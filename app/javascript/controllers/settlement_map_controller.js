import { Controller } from '@hotwired/stimulus'
import * as Leaflet from 'leaflet'
import 'leaflet-providers'
import 'leaflet-extensible'
import 'leaflet.markercluster'

// Settlement map: the settlement pin and boundary plus located records with coordinates, clustered by
// density. Pins are coloured per type and cluster icons show the mix of types; the legend toggles types.
const L = window.L || Leaflet

export default class extends Controller {
  static values = { data: Object, countLabel: String }

  connect() {
    const { settlement, boundary, types, items } = this.dataValue
    this.styles = Object.fromEntries(types.map((t) => [t.key, t]))
    this.map = L.map(this.element, { gestureHandling: true, minZoom: 3 }).setView([settlement.lat, settlement.lng], 12)
    L.tileLayer.provider('OpenStreetMap.Mapnik').addTo(this.map)

    const bounds = L.latLngBounds([[settlement.lat, settlement.lng]])
    if (boundary) {
      const layer = L.geoJSON(boundary, { style: { color: '#0d6efd', weight: 2, fillOpacity: 0.08 }, interactive: false }).addTo(this.map)
      bounds.extend(layer.getBounds())
    }
    L.marker([settlement.lat, settlement.lng], { title: settlement.name, alt: settlement.name }).addTo(this.map)

    this.cluster = L.markerClusterGroup({ iconCreateFunction: (c) => this.clusterIcon(c), maxClusterRadius: 50, showCoverageOnHover: false })
    this.markers = items.map((item) => this.buildMarker(item))
    this.cluster.addLayers(this.markers)
    this.map.addLayer(this.cluster)
    this.markers.forEach((m) => bounds.extend(m.getLatLng()))
    this.map.fitBounds(bounds, { padding: [40, 40], maxZoom: 14 })
  }

  disconnect() {
    this.map?.remove()
  }

  buildMarker(item) {
    const style = this.styles[item.type] || {}
    const icon = L.divIcon({
      className: 'settlement-map__pin',
      html: `<span style="background:${style.color}"><i class="fas ${style.icon}" aria-hidden="true"></i></span>`,
      iconSize: [30, 30], iconAnchor: [15, 15]
    })
    const marker = L.marker([item.lat, item.lng], { icon, title: item.title, alt: item.title })
    const link = document.createElement('a')
    link.href = item.url
    link.textContent = item.title
    const popup = document.createElement('div')
    popup.append(link, document.createElement('br'), Object.assign(document.createElement('small'), { textContent: style.label || '' }))
    marker.bindPopup(popup)
    marker.itemType = item.type
    return marker
  }

  // A pie of the child types (conic-gradient) around the count.
  clusterIcon(cluster) {
    const counts = {}
    cluster.getAllChildMarkers().forEach((m) => { counts[m.itemType] = (counts[m.itemType] || 0) + 1 })
    const total = cluster.getChildCount()
    let at = 0
    const stops = Object.entries(counts).map(([type, n]) => {
      const from = at
      at += (n / total) * 100
      return `${(this.styles[type] || {}).color || '#6c757d'} ${from}% ${at}%`
    })
    return L.divIcon({
      className: 'settlement-map__cluster',
      html: `<span style="background:conic-gradient(${stops.join(',')})"><b aria-label="${total} ${this.countLabelValue}">${total}</b></span>`,
      iconSize: [40, 40]
    })
  }

  toggleType(event) {
    const type = event.target.value
    const layers = this.markers.filter((m) => m.itemType === type)
    if (event.target.checked) this.cluster.addLayers(layers)
    else this.cluster.removeLayers(layers)
  }
}
