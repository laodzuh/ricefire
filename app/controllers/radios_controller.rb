# What the radio is playing, for the player in the sidebar: the tracks and the station's epoch (players work out
# where to be from those and the server's clock), or the stream.
class RadiosController < ApplicationController
  def show
    station = Radio::Station.instance
    response.headers["Cache-Control"] = "no-store"

    render json: {
      now_ms: Radio::Station.now_ms,
      source: source_for(station),
      epoch_ms: station.epoch_ms,
      video_id: station.youtube_video_id,
      tracks: station.tracks.map do |track|
        { id: track.id, name: track.name, duration_ms: track.duration_ms, url: rails_storage_proxy_path(track.audio) }
      end
    }
  end

  private
    def source_for(station)
      if !station.playing_stream?
        "playlist"
      elsif station.youtube_video_id
        "stream"
      else
        "off"
      end
    end
end
