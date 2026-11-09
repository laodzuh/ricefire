import { Controller } from "@hotwired/stimulus"

// The radio in the sidebar. The server says which tracks are on and since when (the station's epoch); from that and
// the server's clock every player works out the same song and position, and checks every few seconds that it's
// still there. A live stream needs no syncing: it's live. Only sound needs a click to start, so it starts off.
const DRIFT_TOLERANCE_SECONDS = 1.5
const CHECK_EVERY_MS = 5000
const YOUTUBE_ORIGIN = "https://www.youtube-nocookie.com"

export default class extends Controller {
  static targets = [ "audio", "screen", "toggle", "now", "volume", "signal" ]
  static values = { url: String }

  // The player is permanent, so Turbo detaches and reattaches it on every page change. Stimulus disconnects and
  // reconnects the same controller then, which mustn't interrupt the music: only the first connect starts it off.
  connect() {
    if (this.on === undefined) {
      this.on = false
      this.clockOffset = 0
      this.volumeTarget.value = this.#storedVolume
      this.#applyVolume()
    } else if (this.on) {
      this.#startChecking()
      this.sync()
    }
    this.#render()
  }

  disconnect() {
    clearInterval(this.timer)
  }

  toggle() {
    this.on ? this.#stop() : this.#start()
  }

  setVolume() {
    try { localStorage.setItem("radio-volume", this.volumeTarget.value) } catch {}
    this.#applyVolume()
  }

  // The station changed: a broadcast replaced the signal
  signalTargetConnected() {
    if (this.on) this.#refresh()
  }

  // Messages from the YouTube player
  receive(event) {
    if (event.origin !== YOUTUBE_ORIGIN || !this.#iframe || event.source !== this.#iframe.contentWindow) return

    let data
    try { data = JSON.parse(event.data) } catch { return }
    if (data.event === "onReady") {
      this.#applyVolume()
      this.#youtube("playVideo")
    }
  }

  sync() {
    if (!this.on || !this.station) return

    if (this.station.source === "playlist") {
      this.#syncPlaylist()
    } else if (this.station.source === "stream") {
      this.#syncStream()
    } else {
      this.#silence()
    }
    this.#render()
  }

  async #start() {
    this.on = true
    this.#render()

    // Let the audio element play later, while this click still counts as one
    this.audioTarget.play().catch(() => {})

    await this.#refresh()
    this.#startChecking()
  }

  #startChecking() {
    clearInterval(this.timer)
    this.timer = setInterval(() => this.sync(), CHECK_EVERY_MS)
  }

  #stop() {
    this.on = false
    clearInterval(this.timer)
    this.#silence()
    this.station = null
    this.#render()
  }

  async #refresh() {
    try {
      const sentAt = Date.now()
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" }, credentials: "same-origin" })
      if (!response.ok) return

      const station = await response.json()
      this.clockOffset = station.now_ms - (sentAt + Date.now()) / 2
      this.station = station
      this.sync()
    } catch {
      // Offline for a moment; the next broadcast or click tries again
    }
  }

  #syncPlaylist() {
    this.#clearScreen()

    const playing = this.#nowPlaying()
    if (!playing) return this.#silence()

    const { track, offsetMs } = playing
    const audio = this.audioTarget
    this.nowName = track.name

    if (audio.dataset.trackId !== String(track.id)) {
      audio.dataset.trackId = track.id
      audio.src = track.url
      audio.addEventListener("loadedmetadata", () => {
        const current = this.#nowPlaying()
        if (current?.track.id === track.id) audio.currentTime = current.offsetMs / 1000
      }, { once: true })
      this.#play()
    } else if (audio.readyState > 0 && Math.abs(audio.currentTime - offsetMs / 1000) > DRIFT_TOLERANCE_SECONDS) {
      audio.currentTime = offsetMs / 1000
      this.#play()
    } else if (audio.paused) {
      this.#play()
    }
  }

  #syncStream() {
    this.audioTarget.pause()
    this.nowName = "Live stream"

    const id = this.station.video_id
    if (this.#iframe?.dataset.videoId === id) return

    const iframe = document.createElement("iframe")
    iframe.dataset.videoId = id
    iframe.title = "Radio live stream"
    iframe.allow = "autoplay; encrypted-media; picture-in-picture"
    iframe.src = `${YOUTUBE_ORIGIN}/embed/${encodeURIComponent(id)}?autoplay=1&enablejsapi=1&playsinline=1&origin=${encodeURIComponent(location.origin)}`
    iframe.addEventListener("load", () => this.#youtube("listening"))

    this.screenTarget.replaceChildren(iframe)
    this.screenTarget.hidden = false
  }

  #nowPlaying() {
    const tracks = this.station?.tracks || []
    const total = tracks.reduce((sum, track) => sum + track.duration_ms, 0)
    if (total <= 0) return

    let offsetMs = (((Date.now() + this.clockOffset - this.station.epoch_ms) % total) + total) % total
    for (const track of tracks) {
      if (offsetMs < track.duration_ms) return { track, offsetMs }
      offsetMs -= track.duration_ms
    }
  }

  #play() {
    this.audioTarget.play().catch(error => {
      // The browser wants a click first (after a reload, say): show the radio as off so the next click starts it
      if (error.name === "NotAllowedError") this.#stop()
    })
  }

  #silence() {
    this.audioTarget.pause()
    this.audioTarget.removeAttribute("src")
    delete this.audioTarget.dataset.trackId
    this.audioTarget.load()
    this.#clearScreen()
    this.nowName = null
  }

  #clearScreen() {
    this.screenTarget.replaceChildren()
    this.screenTarget.hidden = true
  }

  #youtube(command) {
    const message = command === "listening"
      ? { event: "listening", id: "radio" }
      : { event: "command", func: command, args: command === "setVolume" ? [ Number(this.volumeTarget.value) ] : [] }
    this.#iframe?.contentWindow?.postMessage(JSON.stringify(message), YOUTUBE_ORIGIN)
  }

  #applyVolume() {
    this.volumeTarget.style.setProperty("--fill", `${this.volumeTarget.value}%`)
    this.audioTarget.volume = Number(this.volumeTarget.value) / 100
    this.#youtube("setVolume")
  }

  #render() {
    this.element.classList.toggle("radio--on", this.on)
    this.toggleTarget.setAttribute("aria-pressed", this.on)
    this.nowTarget.textContent = this.on ? (this.nowName || "Tuning in…") : "Radio"
    if (this.on && this.station?.source === "off") this.nowTarget.textContent = "Nothing on air"
  }

  get #iframe() {
    return this.screenTarget.querySelector("iframe")
  }

  get #storedVolume() {
    try { return localStorage.getItem("radio-volume") ?? 70 } catch { return 70 }
  }
}
