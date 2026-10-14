# Rich text attachments (Trix and Action Text) as an extension point

How a host app adds a new kind of embedded content to CE's Trix editor and to rendered rich text, using the video block as the worked example. Follow this to add maps, polls, event cards, audio and similar.

## How it works

1. **Editor.** Trix stores an attachment as a `<figure data-trix-attachment="{...}">` with a JSON payload (`sgid`, `contentType`, `content`). The `content` is a small HTML preview shown inside the editor. Trix keeps this figure through edits and removes unknown raw HTML such as `<iframe>`, which is why an iframe pasted into the body does not survive.
2. **Storage.** On save, Action Text turns each figure into `<action-text-attachment sgid="...">`. Only the signed global id is stored, never the embed HTML.
3. **Lookup.** Any Active Record model (or GlobalID-identifiable PORO) that includes `ActionText::Attachable` can be attached. `sgid` resolves it with `GlobalID::Locator`. A missing record renders as nothing.
4. **Rendering.** `render_action_text_content` replaces each attachment by rendering `attachable.to_attachable_partial_path` with a local named after `model_name.element` plus `in_gallery`. The result is then sanitized.
5. **Editor preview.** `to_trix_content_attachment_partial_path` renders the `content` preview used inside Trix.
6. **CE security controls.** CE adds two Blob-only checks that this app extends (see below).

## Adding a new attachment type

1. Make the model attachable: `include ActionText::Attachable` at **module level** of your concern (not inside `included`), so your partial path methods take precedence over Action Text's defaults.
2. Define `to_attachable_partial_path`, `to_trix_content_attachment_partial_path` and `attachable_plain_text_representation`.
3. Write both partials with `<%# locals: (<model_element>:, in_gallery: false) -%>`. Strict locals fail on the `in_gallery` local if it is missing. For a block, `model_name.element` is `video_block`.
4. Allow the class in CE's security controls: add its class name to `NewfoundlandLabradorOnline::ContentSecurityAttachables::ALLOWED`. Decide the render rule in `renderable?` (video blocks render only when public and visible).
5. If the partial emits tags the sanitizer strips (iframe, video), extend `VideoBlockScrubber` narrowly: allowed host, and only inside an `action-text-attachment`.
6. Create the record server side and insert `ActionText::Attachment.from_attachable(record).to_html`. The sgid cannot be built in the browser, so editor UI needs an endpoint that creates or finds the record and returns the sgid and preview, plus a Trix toolbar button (not built yet).
7. Specs: sgid round trip, `to_trix_html` round trip, save accepted, a different attachable still rejected, rendering, non-public held, sanitizer behaviour.

## Where it is wired in this app

| Concern | File |
|---|---|
| Attachable video block, 9x16 ratio | `app/models/concerns/newfoundland_labrador_online/video_block.rb` |
| Allow-list and render rule | `app/models/concerns/newfoundland_labrador_online/content_security_attachables.rb` |
| Scoped iframe scrubber | `app/models/concerns/newfoundland_labrador_online/video_block_scrubber.rb` |
| Post creates and attaches the block | `app/models/concerns/newfoundland_labrador_online/post_video.rb` |
| Partials | `app/views/newfoundland_labrador_online/video_blocks/` |
| Wiring | `config/initializers/better_together_models.rb` |

## Gotchas found

- Trix removes raw iframes on load or edit. Use an attachment, not iframe HTML.
- CE rejects every non-`ActiveStorage::Blob` attachable on save and holds it at render. Both checks need the exception.
- `ActionText::ContentHelper.allowed_tags` is nil by default. A custom scrubber must start from the sanitizer defaults.
- Check ancestors, not the parent, in a scrubber: the iframe sits inside `figure > div`, not directly under the attachment. The parent check passed under the HTML4 sanitizer and failed under HTML5.
- Setting `ActionText::ContentHelper.scrubber` is global to all rich text rendering.
- Blocks cannot be more open than the platform. Specs for public blocks set `seed_privacy_ceiling_exempt`.
- A private post's block is private, so its video shows the held placeholder until the render rule knows the host record.

## Upstream

The Blob-only checks and the 3-ratio validator are CE code patched from the host. CE issues to file: allow-list hook for attachable classes, and a 9:16 aspect ratio on `Content::VideoBlock`. Remove the host patches when they ship.
