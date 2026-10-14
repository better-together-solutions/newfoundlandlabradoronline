import { Controller } from '@hotwired/stimulus'

// Reloads a same-origin camera image about once a minute while the tab is visible. The label shows
// when the camera took the frame (X-Frame-Captured-At), not when the page reloaded it. A failed
// load keeps the last good frame. The minute in the query string lets a CDN cache each frame.
export default class extends Controller {
  static targets = ['image', 'time']
  static values = { interval: { type: Number, default: 60000 }, zone: { type: String, default: 'America/St_Johns' } }

  connect () {
    this.source = this.imageTarget.getAttribute('src').split('?')[0]
    if (!this.timeTarget.textContent.trim()) this.refresh()
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect () {
    clearInterval(this.timer)
    this.release()
  }

  async refresh () {
    if (document.hidden) return
    try {
      const response = await fetch(`${this.source}?t=${Math.floor(Date.now() / 60000)}`)
      if (!response.ok) return
      const captured = response.headers.get('X-Frame-Captured-At') || response.headers.get('Last-Modified')
      const blob = await response.blob()
      this.show(URL.createObjectURL(blob), captured)
    } catch (error) {
      // keep the last frame
    }
  }

  show (url, captured) {
    const previous = this.objectUrl
    this.imageTarget.onload = () => { if (previous) URL.revokeObjectURL(previous) }
    this.imageTarget.src = url
    this.objectUrl = url
    this.stamp(captured)
  }

  release () {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
  }

  stamp (captured) {
    const when = captured ? new Date(captured) : null
    if (!when || Number.isNaN(when.getTime())) return
    this.timeTarget.dateTime = when.toISOString()
    this.timeTarget.textContent = when.toLocaleTimeString([], {
      hour: 'numeric', minute: '2-digit', timeZone: this.zoneValue, timeZoneName: 'short'
    })
  }
}
