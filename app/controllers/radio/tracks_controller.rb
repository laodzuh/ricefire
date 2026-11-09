class Radio::TracksController < ApplicationController
  MAX_FILES_PER_UPLOAD = 50

  before_action :ensure_can_administer
  before_action :set_track, only: %i[ update destroy ]

  def index
    @station = Radio::Station.instance
    @tracks = Radio::Track.ordered.to_a
  end

  def create
    files = Array(params[:audio_files]).compact_blank.first(MAX_FILES_PER_UPLOAD)
    tracks = files.map { |file| Radio::Track.create(audio: file) }

    if tracks.any? && tracks.all?(&:persisted?)
      redirect_to radio_tracks_url, notice: "✓"
    else
      redirect_to radio_tracks_url, alert: upload_problem(files, tracks)
    end
  end

  # Moves a track up or down the list
  def update
    @track.move(params[:direction] == "up" ? -1 : 1)
    redirect_to radio_tracks_url
  end

  def destroy
    @track.remove
    redirect_to radio_tracks_url
  end

  private
    def set_track
      @track = Radio::Track.find(params[:id])
    end

    def upload_problem(files, tracks)
      if files.empty?
        "Choose some songs to upload."
      else
        tracks.reject(&:persisted?).flat_map { |track| track.errors.full_messages }.first || "Some songs couldn't be added."
      end
    end
end
