require "test_helper"

class Radio::TracksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
    assert users(:david).can_administer?
  end

  test "the radio page" do
    ready_track("Night Drive", seconds: 200)

    get radio_tracks_url

    assert_response :success
    assert_select "#radio_tracks li", text: /Night Drive/
    assert_select "#radio_tracks li", text: /3:20/
  end

  test "uploading songs" do
    assert_difference -> { Radio::Track.count }, 2 do
      assert_enqueued_jobs 2, only: Radio::TrackProcessingJob do
        post radio_tracks_url, params: { audio_files: [ audio_file("mp3"), audio_file("flac") ] }
      end
    end

    assert_redirected_to radio_tracks_url
  end

  test "uploading nothing" do
    post radio_tracks_url, params: { audio_files: [ "" ] }

    assert_redirected_to radio_tracks_url
    assert_equal "Choose some songs to upload.", flash[:alert]
  end

  test "moving and removing songs" do
    a = ready_track("A", seconds: 10, position: 1)
    b = ready_track("B", seconds: 10, position: 2)

    patch radio_track_url(b, direction: "up")
    assert_equal %w[ B A ], Radio::Station.instance.tracks.map(&:title)

    delete radio_track_url(a)
    assert_equal %w[ B ], Radio::Station.instance.tracks.map(&:title)
  end

  test "switching to the stream" do
    assert_turbo_stream_broadcasts :radio do
      patch radio_station_url, params: { radio_station: { source: "stream", stream_url: "https://youtu.be/jfKfPfyJRdk" } }
    end

    assert_redirected_to radio_tracks_url
    station = Radio::Station.instance
    assert_equal "stream", station.source
    assert_equal "jfKfPfyJRdk", station.youtube_video_id
  end

  test "a stream that isn't YouTube" do
    patch radio_station_url, params: { radio_station: { stream_url: "https://example.com/evil" } }

    assert_equal "Stream url must be a YouTube video or live stream link", flash[:alert]
    assert_nil Radio::Station.instance.stream_url
  end

  test "only admins run the radio" do
    sign_in :kevin
    track = ready_track("A", seconds: 10)

    get radio_tracks_url
    assert_response :forbidden

    post radio_tracks_url, params: { audio_files: [ audio_file("mp3") ] }
    assert_response :forbidden

    delete radio_track_url(track)
    assert_response :forbidden

    patch radio_station_url, params: { radio_station: { source: "stream" } }
    assert_response :forbidden

    assert Radio::Track.exists?(track.id)
  end
end
