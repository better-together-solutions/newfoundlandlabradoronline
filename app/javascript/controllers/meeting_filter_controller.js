import { Controller } from '@hotwired/stimulus'

// Shows or hides meeting rows by category. Every category starts on; without JavaScript all rows show.
export default class extends Controller {
  static targets = ['toggle', 'row', 'empty']

  toggle(event) {
    const button = event.currentTarget
    button.setAttribute('aria-pressed', button.getAttribute('aria-pressed') === 'true' ? 'false' : 'true')
    this.apply()
  }

  apply() {
    const active = new Set(this.toggleTargets.filter((b) => b.getAttribute('aria-pressed') === 'true').map((b) => b.dataset.category))
    let shown = 0
    this.rowTargets.forEach((row) => {
      const visible = active.has(row.dataset.category)
      row.hidden = !visible
      if (visible) shown += 1
    })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0
  }
}
