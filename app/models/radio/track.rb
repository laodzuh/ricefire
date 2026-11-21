# A song on the station. It's uploaded as is, then Radio::TrackProcessingJob reads its length and tags and, if
# browsers can't play it or it's lossless and heavy, converts it to AAC. Only then is it ready to play.
class Radio::Track < ApplicationRecord
  MAX_BYTES = 100.megabytes
  # All tracks together, so one big upload can't fill the server's disk
  LIBRARY_MAX_BYTES = 5.gigabytes

  has_one_attached :audio

  scope :ready, -> { where(status: "ready") }
  scope :ordered, -> { order(:position, :id) }

  validates :audio, presence: true, on: :create
  validate :audio_is_small_enough, :library_has_room, on: :create

  before_validation -> { self.position ||= (self.class.maximum(:position) || 0) + 1 }, on: :create
  after_create_commit -> { Radio::TrackProcessingJob.perform_later(self) }

  def ready?
    status == "ready"
  end

  def failed?
    status == "failed"
  end

  def name
    [ artist, title ].compact_blank.join(" – ").presence || "Untitled"
  end

  # Swaps places with the track before (-1) or after (1) it
  def move(direction)
    neighbor = self.class.ordered.where(direction.negative? ? [ "position < ?", position ] : [ "position > ?", position ])
      .reorder(position: direction.negative? ? :desc : :asc).first
    return unless neighbor

    Radio::Station.instance.preserving_position do
      transaction do
        mine, theirs = position, neighbor.position
        update!(position: theirs)
        neighbor.update!(position: mine)
      end
    end
  end

  def remove
    Radio::Station.instance.preserving_position { destroy! }
  end

  # Bytes stored for every track's audio
  def self.library_bytes
    ActiveStorage::Blob.joins(:attachments)
      .where(active_storage_attachments: { record_type: name, name: "audio" })
      .sum(:byte_size)
  end

  private
    def audio_is_small_enough
      if audio.attached? && audio.blob.byte_size > MAX_BYTES
        errors.add(:audio, "is too big (the limit is #{human_size(MAX_BYTES)})")
      end
    end

    def library_has_room
      if audio.attached? && self.class.library_bytes + audio.blob.byte_size > LIBRARY_MAX_BYTES
        errors.add(:base, "The radio library is full (the limit is #{human_size(LIBRARY_MAX_BYTES)}). Remove some songs first.")
      end
    end

    def human_size(bytes)
      ActiveSupport::NumberHelper.number_to_human_size(bytes)
    end
end
