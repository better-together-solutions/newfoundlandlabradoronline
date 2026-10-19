# Live current image on community and settlement pages

The Corner Brook Online community page and the Corner Brook settlement page show the latest mill camera frame, refreshed about once a minute, without any post per update.

## How it works

1. `NewfoundlandLabradorOnline::LiveImage` fetches the public source (default `https://ai.btsdev.ca/webhook/timelapse-current`, override with `LIVE_IMAGE_CORNER_BROOK_URL`), keeps only a JPEG or PNG up to 8 MB, gives it the same 16:9 crop as the post covers (full width, 3 percent off the top, so the roof edge is excluded), resizes it to 1920x1080, compresses it (JPEG quality 80, progressive, metadata stripped, typically 100 to 300 KB) and caches it for 60 seconds in the Rails cache. If the source fails, the last good frame keeps being served for up to a day.
2. The frame's capture time is read from the EXIF `DateTimeOriginal` of the original (camera local time, America/St_Johns). `GET /live/corner-brook.jpg` (`LiveImagesController`) serves the cached frame from this host with `Cache-Control: public, max-age=30, s-maxage=60, stale-while-revalidate=120`, an ETag, and `Last-Modified` plus `X-Frame-Captured-At` set to when the camera took the frame (not when it was fetched). Same origin means no CSP change. Unknown cameras return 404, and 503 with `Retry-After` when nothing has ever been fetched.
3. The card (`newfoundland_labrador_online/live_images/_card`) renders in the About section of the community page and of the settlement page, for records listed in `LiveImage::RECORDS` (community `corner-brook-online`, settlement `corner-brook`). Both pages are host overrides copied from community-engine-rails `929bb51a9492` with one added card: `app/views/better_together/communities/show.html.erb` and `app/views/better_together/geography/settlements/show.html.erb`. A composable way to choose page elements per community or record is out of scope here. The `live-image` Stimulus controller fetches the image every minute while the tab is visible, swaps it in as a blob URL (allowed by the CSP `img-src blob:`), and shows the capture time in Corner Brook time under "Photo taken". A failed fetch keeps the last good frame. New frames only exist about every 74 seconds and reach the page after the sync interval and the 60 second caches, so the picture often stays the same for a few reloads.

## Adding another camera or community

Add the source URL to `LiveImage::SOURCES` and the record's model and identifier to `LiveImage::RECORDS`. Other record types need their show view overridden the same way.

## Notes

- The source is the public n8n relay, which is uncached and about 1.1 MB per frame; viewers never reach it, only this app does, about once a minute.
- Re-diff both `show` views when the CE pin moves. The Corner Brook settlement's own community is private, so the card is shown on the settlement page, not that community page.
- Production check after deploy: the response headers on `/live/corner-brook.jpg` (the app can be fronted by Cloudflare, so look for `cf-cache-status`).
