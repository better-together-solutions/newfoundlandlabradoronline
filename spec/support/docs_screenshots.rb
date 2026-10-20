# frozen_string_literal: true

require 'fileutils'

# Desktop and mobile captures for PR documentation, plain and annotated (numbered outlines on the callout targets).
# The gem's CapybaraScreenshotEngine writes under the gem root, so the host app keeps its own small helper.
module DocsScreenshots
  DEVICES = { desktop: [1440, 1600], mobile: [430, 1400] }.freeze
  ROOT = Rails.root.join('docs/screenshots')

  module_function

  # callouts: [{ selector:, title: }]. Writes <slug>.png and <slug>_annotated.png per device; returns the paths.
  def capture(page, slug, callouts: [])
    DEVICES.flat_map do |device, (width, height)|
      page.driver.browser.manage.window.resize_to(width, height)
      yield if block_given?
      wait_for_map(page)
      [save(page, device, slug), save_annotated(page, device, slug, callouts)].compact
    end
  end

  def save(page, device, slug)
    path = path_for(device, slug)
    page.save_screenshot(path)
    path
  end

  def save_annotated(page, device, slug, callouts)
    return if callouts.empty?

    page.execute_script(ANNOTATE_JS, callouts.map { |c| c.slice(:selector, :title) })
    path = path_for(device, "#{slug}_annotated")
    page.save_screenshot(path)
    page.execute_script("document.querySelectorAll('[data-docs-callout]').forEach(function (n) { n.remove() })")
    path
  end

  def path_for(device, name)
    ROOT.join(device.to_s).tap { |dir| FileUtils.mkdir_p(dir) }.join("#{name}.png").to_s
  end

  def wait_for_map(page)
    page.has_css?('.leaflet-container', wait: 10)
    sleep 2 # let the outline and tiles settle
  end

  # Scrolls each target to the centre of the frame, outlines it and adds a numbered badge. The last target stays framed.
  ANNOTATE_JS = <<~JS
    (function (callouts) {
      callouts.forEach(function (callout, index) {
        var el = document.querySelector(callout.selector)
        if (!el) { throw new Error('callout target missing: ' + callout.selector) }
        var rect = el.getBoundingClientRect()
        var box = document.createElement('div')
        box.setAttribute('data-docs-callout', index + 1)
        box.style.cssText = 'position:absolute;pointer-events:none;z-index:99999;border:3px solid #d6336c;border-radius:6px;' +
          'left:' + (rect.left + window.scrollX - 4) + 'px;top:' + (rect.top + window.scrollY - 4) + 'px;' +
          'width:' + (rect.width + 8) + 'px;height:' + (rect.height + 8) + 'px'
        var badge = document.createElement('span')
        badge.textContent = index + 1
        badge.style.cssText = 'position:absolute;top:-14px;left:-14px;width:28px;height:28px;border-radius:50%;background:#d6336c;' +
          'color:#fff;font:700 15px/28px sans-serif;text-align:center'
        box.appendChild(badge)
        document.body.appendChild(box)
      })
    })(arguments[0])
  JS
end
