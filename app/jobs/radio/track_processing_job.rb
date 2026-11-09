require "open3"

# Reads an uploaded song's length and tags with ffprobe, and converts it to AAC unless it's already MP3 or AAC,
# which every browser plays and which are small enough to stream all day. Then the track goes on air.
class Radio::TrackProcessingJob < ApplicationJob
  PLAYABLE_CODECS = %w[ mp3 aac ].freeze
  AAC_BITRATE = "192k"

  discard_on ActiveJob::DeserializationError

  def perform(track)
    track.audio.open do |file|
      probe = probe(file.path)
      stream = Array(probe["streams"]).find { |s| s["codec_type"] == "audio" }
      duration = Float(probe.dig("format", "duration") || stream&.dig("duration"), exception: false)

      if stream.nil? || duration.nil? || duration <= 0
        track.update!(status: "failed")
      else
        convert(track, file.path) unless PLAYABLE_CODECS.include?(stream["codec_name"])

        tags = tags_from(probe, stream)
        Radio::Station.instance.preserving_position do
          track.update!(
            title: track.title.presence || tags["title"].presence || File.basename(track.audio.filename.to_s, ".*"),
            artist: track.artist.presence || tags["artist"].presence || tags["album_artist"].presence,
            duration_ms: (duration * 1000).round,
            status: "ready")
        end
      end
    end
  rescue ActiveStorage::FileNotFoundError, ActiveRecord::RecordNotFound
    # Removed while it was being processed
  rescue => error
    Rails.logger.warn "Radio track #{track.id} failed to process: #{error.class}: #{error.message}"
    track.update_columns(status: "failed") if track.persisted?
  ensure
    broadcast_tracks if track
  end

  private
    def probe(path)
      output, status = Open3.capture2(ffprobe, "-v", "error", "-print_format", "json", "-show_format", "-show_streams", path)
      status.success? ? JSON.parse(output) : {}
    end

    def convert(track, path)
      Tempfile.create([ "radio", ".m4a" ]) do |output|
        _, error, status = Open3.capture3(ffmpeg, "-nostdin", "-v", "error", "-y", "-i", path,
          "-map", "0:a:0", "-vn", "-c:a", "aac", "-b:a", AAC_BITRATE, "-movflags", "+faststart", output.path)
        raise "ffmpeg: #{error.lines.last.to_s.strip}" unless status.success?

        track.audio.attach(io: File.open(output.path), content_type: "audio/mp4",
          filename: "#{File.basename(track.audio.filename.to_s, ".*")}.m4a")
      end
    end

    def tags_from(probe, stream)
      [ probe.dig("format", "tags"), stream["tags"] ].compact.reduce({}) { |tags, more| more.merge(tags) }
        .transform_keys(&:downcase).transform_values { |value| value.to_s.strip.first(200) }
    end

    def ffprobe
      ActiveStorage.paths[:ffprobe] || "ffprobe"
    end

    def ffmpeg
      ActiveStorage.paths[:ffmpeg] || "ffmpeg"
    end

    def broadcast_tracks
      Turbo::StreamsChannel.broadcast_replace_to :radio_admin, target: "radio_tracks",
        partial: "radio/tracks/tracks", locals: { tracks: Radio::Track.ordered.to_a }
    rescue => error
      Rails.logger.warn "Could not broadcast radio tracks: #{error.class}"
    end
end
