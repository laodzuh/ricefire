# The station plays the ready tracks in order, looping, as if it had been playing since epoch_ms. Everyone works out
# what's on from that, so nobody needs to host it and listeners join mid-song in step with everyone else. When the
# tracks change, the epoch moves so whatever is playing keeps playing.
#
# The station plays its stream instead when it's set to, or when there are no tracks ready.
class Radio::Station < ApplicationRecord
  SOURCES = %w[ playlist stream ].freeze
  YOUTUBE_ID = /\A[\w-]{11}\z/
  YOUTUBE_HOSTS = %w[ youtube.com youtu.be youtube-nocookie.com music.youtube.com ].freeze

  validates :source, inclusion: { in: SOURCES }
  validate :stream_url_is_a_youtube_video, if: -> { stream_url.present? }

  class << self
    def instance
      first || create!(epoch_ms: now_ms)
    end

    def now_ms
      (Time.current.to_r * 1000).to_i
    end
  end

  def tracks
    Radio::Track.ready.ordered.to_a
  end

  def playing_stream?
    source == "stream" || tracks.empty?
  end

  # The track playing at a moment, and how far into it
  def now_playing(at: self.class.now_ms, list: tracks)
    total = list.sum(&:duration_ms)
    return if total.zero?

    offset = (at - epoch_ms) % total
    list.each do |track|
      return [ track, offset ] if offset < track.duration_ms
      offset -= track.duration_ms
    end
  end

  # Changes the tracks without interrupting the one playing. If it's gone, the track now in its place starts.
  def preserving_position
    playing, offset = now_playing
    index = tracks.index(playing) if playing

    result = yield

    list = tracks
    if list.any?
      start = if playing && (new_index = list.index(playing))
        list.take(new_index).sum(&:duration_ms) + offset
      else
        list.take([ index.to_i, list.size - 1 ].min).sum(&:duration_ms)
      end
      update!(epoch_ms: self.class.now_ms - start)
    end

    broadcast_change
    result
  end

  def youtube_video_id
    return if stream_url.blank?

    uri = URI.parse(stream_url.strip)
    return unless uri.is_a?(URI::HTTP) && YOUTUBE_HOSTS.include?(uri.host.to_s.downcase.delete_prefix("www.").delete_prefix("m."))

    id = if uri.host.to_s.end_with?("youtu.be")
      uri.path.delete_prefix("/")
    elsif (query = Rack::Utils.parse_query(uri.query.to_s)["v"])
      query
    else
      uri.path[%r{/(?:live|embed|shorts)/([\w-]{11})}, 1]
    end

    id if id.to_s.match?(YOUTUBE_ID)
  rescue URI::InvalidURIError
    nil
  end

  # Tells listeners to fetch the station again
  def broadcast_change
    Turbo::StreamsChannel.broadcast_replace_to :radio, target: "radio_signal",
      html: %(<span id="radio_signal" data-radio-target="signal" data-version="#{self.class.now_ms}"></span>)
  rescue => error
    Rails.logger.warn "Could not broadcast a radio change: #{error.class}"
  end

  private
    def stream_url_is_a_youtube_video
      errors.add(:stream_url, "must be a YouTube video or live stream link") unless youtube_video_id
    end
end
