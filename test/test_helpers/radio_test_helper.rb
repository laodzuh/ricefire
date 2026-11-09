module RadioTestHelper
  # A real song file: a short tone with tags, made by ffmpeg
  def audio_file(format, seconds: 2, title: "Test Tone", artist: "Ricefire")
    path = File.join(Dir.mktmpdir, "tone.#{format}")
    system("ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i", "sine=frequency=440:duration=#{seconds}",
      "-metadata", "title=#{title}", "-metadata", "artist=#{artist}", path, exception: true)

    content_type = { "mp3" => "audio/mpeg", "flac" => "audio/flac", "m4a" => "audio/mp4", "wav" => "audio/wav" }.fetch(format)
    Rack::Test::UploadedFile.new(path, content_type)
  end

  def ready_track(title, seconds:, position: nil)
    Radio::Track.create!(audio: audio_file("mp3", seconds: 1, title: title)).tap do |track|
      track.update_columns(title: title, duration_ms: seconds * 1000, status: "ready", position: position || track.position)
    end
  end
end
