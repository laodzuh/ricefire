class Radio::StationsController < ApplicationController
  before_action :ensure_can_administer

  def update
    station = Radio::Station.instance

    if station.update(params.require(:radio_station).permit(:source, :stream_url))
      station.broadcast_change
      redirect_to radio_tracks_url, notice: "✓"
    else
      redirect_to radio_tracks_url, alert: station.errors.full_messages.first
    end
  end
end
