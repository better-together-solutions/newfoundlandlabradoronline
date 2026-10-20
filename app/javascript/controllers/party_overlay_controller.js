import { Controller } from '@hotwired/stimulus'

// Draws coloured, clickable areas (for example districts in their member's party colour) on a CE map. Each overlay
// is { geometry, color, popup }. The CE map controller may have fired map:ready before this one connects, so it
// draws at once when the map exists and otherwise waits for the event.
export default class extends Controller {
  static values = { overlays: Array }

  connect () {
    this.onReady = (event) => this.draw(event.detail.map)
    this.element.addEventListener('map:ready', this.onReady)
    const map = this.application.getControllerForElementAndIdentifier(this.element, 'better_together--map')?.map
    if (map) this.draw(map)
  }

  disconnect () {
    this.element.removeEventListener('map:ready', this.onReady)
    this.layer?.remove()
  }

  draw (map) {
    if (this.layer) return
    this.layer = L.layerGroup().addTo(map)
    this.overlaysValue.forEach((overlay) => {
      L.geoJSON(overlay.geometry, {
        style: { color: overlay.color, weight: 1.5, fillColor: overlay.color, fillOpacity: 0.45 }
      }).bindPopup(overlay.popup).addTo(this.layer)
    })
  }
}
