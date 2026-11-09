require "test_helper"

class Radio::StationTest < ActiveSupport::TestCase
  setup do
    @station = Radio::Station.instance
    @a = ready_track("A", seconds: 60, position: 1)
    @b = ready_track("B", seconds: 120, position: 2)
    @c = ready_track("C", seconds: 30, position: 3)
    @station.update!(epoch_ms: 1_000_000)
  end

  test "works out what's playing from the epoch, looping" do
    assert_equal [ @a, 0 ], @station.now_playing(at: 1_000_000)
    assert_equal [ @b, 15_000 ], @station.now_playing(at: 1_000_000 + 75_000)
    assert_equal [ @c, 29_999 ], @station.now_playing(at: 1_000_000 + 209_999)
    assert_equal [ @a, 5_000 ], @station.now_playing(at: 1_000_000 + 210_000 + 5_000)
  end

  test "keeps the playing track playing when another is added" do
    travel_to_station_time(75_000) do
      assert_equal [ @b, 15_000 ], @station.now_playing

      @station.preserving_position { ready_track("D", seconds: 45) }

      assert_equal [ @b, 15_000 ], @station.reload.now_playing
    end
  end

  test "keeps the playing track playing when the list is reordered" do
    travel_to_station_time(75_000) do
      @b.move(-1)

      assert_equal %w[ B A C ], @station.reload.tracks.map(&:title)
      assert_equal [ @b, 15_000 ], @station.now_playing
    end
  end

  test "removing the playing track starts the one in its place" do
    travel_to_station_time(75_000) do
      @b.remove

      assert_equal [ @c, 0 ], @station.reload.now_playing
    end
  end

  test "removing the last playing track starts the new last one" do
    travel_to_station_time(200_000) do
      assert_equal @c, @station.now_playing.first

      @c.remove

      assert_equal [ @b, 0 ], @station.reload.now_playing
    end
  end

  test "plays the stream when asked to or when nothing is ready" do
    assert_not @station.playing_stream?

    @station.update!(source: "stream")
    assert @station.playing_stream?

    @station.update!(source: "playlist")
    Radio::Track.update_all(status: "processing")
    assert @station.playing_stream?
  end

  test "reads YouTube links" do
    {
      "https://www.youtube.com/watch?v=jfKfPfyJRdk" => "jfKfPfyJRdk",
      "https://youtu.be/jfKfPfyJRdk?si=abc" => "jfKfPfyJRdk",
      "https://www.youtube.com/live/jfKfPfyJRdk" => "jfKfPfyJRdk",
      "https://www.youtube.com/embed/jfKfPfyJRdk" => "jfKfPfyJRdk",
      "https://www.youtube.com/@LofiGirl" => nil,
      "javascript:alert(1)" => nil,
      "https://example.com/watch?v=\"><script>" => nil,
      "https://example.com/watch?v=jfKfPfyJRdk" => nil,
      "https://m.youtube.com/watch?v=jfKfPfyJRdk" => "jfKfPfyJRdk"
    }.each do |url, id|
      @station.stream_url = url
      id ? assert_equal(id, @station.youtube_video_id, url) : assert_nil(@station.youtube_video_id, url)
    end
  end

  test "only takes YouTube video links for the stream" do
    assert_not @station.update(stream_url: "https://example.com/music.mp3")
    assert @station.update(stream_url: "https://youtu.be/jfKfPfyJRdk")
    assert @station.update(stream_url: "")
  end

  test "only plays known sources" do
    assert_not @station.update(source: "spotify")
  end

  private
    # Freezes time at a point in the station's loop
    def travel_to_station_time(offset_ms, &)
      travel_to(Time.at(Rational(@station.epoch_ms + offset_ms, 1000)), &)
    end
end
