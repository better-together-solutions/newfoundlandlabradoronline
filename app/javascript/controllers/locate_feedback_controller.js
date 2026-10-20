import { Controller } from '@hotwired/stimulus'

// Visible feedback for the CE map "locate me" button: a spinning globe while the position is being fetched, a check
// once found, and a zoom that frames the accuracy circle. Re-diff against CE's map controller when the pin moves.
export default class extends Controller {
  connect () {
    this.button = this.element.querySelector('[data-geolocation-button]')
    if (!this.button) return
    this.label = this.button.textContent.trim()
    this.observer = new MutationObserver(() => this.render())
    this.observer.observe(this.element, { attributes: true, attributeFilter: ['data-geolocation-state'] })
    this.onLocated = (event) => this.frame(event.detail)
    this.element.addEventListener('map:located', this.onLocated)
  }

  disconnect () {
    this.observer?.disconnect()
    this.element.removeEventListener('map:located', this.onLocated)
  }

  render () {
    const icons = { locating: 'fa-globe fa-spin', located: 'fa-check' }
    const icon = icons[this.element.dataset.geolocationState]
    this.button.replaceChildren()
    if (icon) {
      const el = document.createElement('i')
      el.className = `fas ${icon} me-1`
      el.setAttribute('aria-hidden', 'true')
      this.button.append(el)
    }
    this.button.append(this.label)
    this.button.classList.toggle('btn-success', this.element.dataset.geolocationState === 'located')
    this.button.classList.toggle('btn-secondary', this.element.dataset.geolocationState !== 'located')
  }

  frame ({ latlng, accuracy }) {
    const map = this.application.getControllerForElementAndIdentifier(this.element, 'better_together--map')?.map
    if (!map) return
    const radius = Math.max(Number(accuracy) || 0, 250)
    map.fitBounds(L.latLng(latlng).toBounds(radius * 2), { maxZoom: 16 })
  }
}
