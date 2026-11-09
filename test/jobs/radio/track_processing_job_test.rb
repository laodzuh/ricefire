require "test_helper"

class Radio::TrackProcessingJobTest < ActiveJob::TestCase
  test "an MP3 plays as it is, with its tags and length" do
    track = Radio::Track.create!(audio: audio_file("mp3", seconds: 3, title: "Night Drive", artist: "Brent"))

    Radio::TrackProcessingJob.perform_now(track)
    track.reload

    assert track.ready?
    assert_equal "Night Drive", track.title
    assert_equal "Brent", track.artist
    assert_in_delta 3000, track.duration_ms, 150
    assert_equal "audio/mpeg", track.audio.blob.content_type
  end

  test "FLAC is converted to AAC" do
    track = Radio::Track.create!(audio: audio_file("flac", seconds: 2, title: "Lossless"))

    Radio::TrackProcessingJob.perform_now(track)
    track.reload

    assert track.ready?
    assert_equal "Lossless", track.title
    assert_equal "audio/mp4", track.audio.blob.content_type
    assert track.audio.filename.to_s.end_with?(".m4a")
    assert_in_delta 2000, track.duration_ms, 150
  end

  test "untagged songs are named after their file" do
    path = File.join(Dir.mktmpdir, "my favorite song.wav")
    system("ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i", "sine=duration=1", path, exception: true)
    track = Radio::Track.create!(audio: Rack::Test::UploadedFile.new(path, "audio/wav"))

    Radio::TrackProcessingJob.perform_now(track)

    assert_equal "my favorite song", track.reload.title
    assert track.ready?
  end

  test "files that aren't audio fail" do
    path = File.join(Dir.mktmpdir, "fake.mp3")
    File.write(path, "not music")
    track = Radio::Track.create!(audio: Rack::Test::UploadedFile.new(path, "audio/mpeg"))

    Radio::TrackProcessingJob.perform_now(track)

    assert track.reload.failed?
  end

  test "a processed track goes on air and tells listeners" do
    track = Radio::Track.create!(audio: audio_file("mp3"))

    assert_turbo_stream_broadcasts :radio do
      Radio::TrackProcessingJob.perform_now(track)
    end
    assert_includes Radio::Station.instance.tracks, track.reload
  end
end
