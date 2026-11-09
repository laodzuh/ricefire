require "test_helper"

class RadiosControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin
  end

  test "members get the station's tracks and clock" do
    track = ready_track("Night Drive", seconds: 200)

    get radio_url(format: :json)

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    station = response.parsed_body
    assert_equal "playlist", station["source"]
    assert_in_delta Radio::Station.now_ms, station["now_ms"], 5_000
    assert_equal Radio::Station.instance.epoch_ms, station["epoch_ms"]
    assert_equal [ track.id ], station["tracks"].map { it["id"] }
    assert_equal 200_000, station["tracks"].first["duration_ms"]
    assert_match %r{/rails/active_storage/blobs/proxy/}, station["tracks"].first["url"]
  end

  test "songs still processing aren't on air" do
    Radio::Track.create!(audio: audio_file("mp3"))

    get radio_url(format: :json)

    assert_empty response.parsed_body["tracks"]
  end

  test "the stream plays when there are no songs" do
    Radio::Station.instance.update!(stream_url: "https://youtu.be/jfKfPfyJRdk")

    get radio_url(format: :json)

    assert_equal "stream", response.parsed_body["source"]
    assert_equal "jfKfPfyJRdk", response.parsed_body["video_id"]
  end

  test "nothing on air" do
    get radio_url(format: :json)

    assert_equal "off", response.parsed_body["source"]
  end

  test "the player is in the sidebar for everyone signed in" do
    get user_profile_url

    assert_select "#radio[data-turbo-permanent][data-controller=radio]"
  end

  test "not for people who aren't signed in" do
    reset!

    get radio_url(format: :json)

    assert_response :redirect
  end
end
