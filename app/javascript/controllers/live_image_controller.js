import { Controller } from '@hotwired/stimulus'

// Reloads a same-origin camera image about once a minute while the tab is visible. A failed
// load keeps the last good frame. The minute in the query string lets a CDN cache each frame.
export default class extends Controller {
  static targets = ['image', 'time']
  static values = { interval: { type: Number, default: 60000 } }

  connect () {
    this.source = this.imageTarget.getAttribute('src').split('?')[0]
    this.stamp()
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect () {
    clearInterval(this.timer)
  }

  refresh () {
    if (document.hidden) return
    const next = new Image()
    next.onload = () => {
      this.imageTarget.src = next.src
      this.stamp()
    }
    next.src = `${this.source}?t=${Math.floor(Date.now() / 60000)}`
  }

  stamp () {
    this.timeTarget.textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  }
}
