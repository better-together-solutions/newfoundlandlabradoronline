import { Controller } from '@hotwired/stimulus'

// Fits a CE map to its drawn boundary. The CE map controller zooms to a lone pin (a settlement with no other places
// mapped), which can cut the boundary off; this refits to the boundary and any pins together. It acts at once when
// the map exists and otherwise waits for map:ready, as party-overlay does.
export default class extends Controller {
  connect () {
    this.onReady = () => this.fit()
    this.element.addEventListener('map:ready', this.onReady)
    this.fit()
  }

  disconnect () {
    this.element.removeEventListener('map:ready', this.onReady)
  }

  fit () {
    const controller = this.application.getControllerForElementAndIdentifier(this.element, 'better_together--map')
    const bounds = controller?.boundaryLayer?.getBounds()
    if (!bounds?.isValid()) return

    controller.markers.forEach((marker) => bounds.extend(marker.getLatLng()))
    controller.map.fitBounds(bounds, { padding: [20, 20] })
  }
}
