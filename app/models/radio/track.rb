# A song on the station. It's uploaded as is, then Radio::TrackProcessingJob reads its length and tags and, if
# browsers can't play it or it's lossless and heavy, converts it to AAC. Only then is it ready to play.
class Radio::Track < ApplicationRecord
  MAX_BYTES = 300.megabytes

  has_one_attached :audio

  scope :ready, -> { where(status: "ready") }
  scope :ordered, -> { order(:position, :id) }

  validates :audio, presence: true, on: :create
  validate :audio_is_small_enough, on: :create

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

  private
    def audio_is_small_enough
      errors.add(:audio, "is too big (the limit is 300 MB)") if audio.attached? && audio.blob.byte_size > MAX_BYTES
    end
end
