# Live current image on a community page

The Corner Brook Online community page shows the latest mill camera frame, refreshed about once a minute, without any post per update.

## How it works

1. `NewfoundlandLabradorOnline::LiveImage` fetches the public source (default `https://ai.btsdev.ca/webhook/timelapse-current`, override with `LIVE_IMAGE_CORNER_BROOK_URL`), keeps only a JPEG or PNG up to 8 MB, crops it to 16:9 (top anchored) at 1280x720 and caches it for 60 seconds in the Rails cache. If the source fails, the last good frame keeps being served for up to a day.
2. `GET /live/corner-brook.jpg` (`LiveImagesController`) serves the cached frame from this host with `Cache-Control: public, max-age=30, s-maxage=60, stale-while-revalidate=120`, an ETag and Last-Modified. Same origin means no CSP change. Unknown cameras return 404, and 503 with `Retry-After` when nothing has ever been fetched.
3. The community page (host override `app/views/better_together/communities/show.html.erb`, copied from community-engine-rails `dfad67df6da4` with one added card) renders `newfoundland_labrador_online/live_images/_card` for communities listed in `LiveImage::COMMUNITIES`. The `live-image` Stimulus controller reloads the image every minute while the tab is visible and keeps the last good frame on error.

## Adding another camera or community

Add the source URL to `LiveImage::SOURCES` and the community identifier to `LiveImage::COMMUNITIES`.

## Notes

- The source is the public n8n relay, which is uncached and about 1.1 MB per frame; viewers never reach it, only this app does, about once a minute.
- Re-diff the communities `show` view when the CE pin moves.
- Production check after deploy: the response headers on `/live/corner-brook.jpg` (the app can be fronted by Cloudflare, so look for `cf-cache-status`).
