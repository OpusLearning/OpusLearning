# API reference

Verified against the vendor documentation in September 2026. If a call
returns a validation error on a field named here, re-check the live docs
before working around it.

## Kie.ai

Base URL `https://api.kie.ai`. Auth header `Authorization: Bearer <KIE_API_KEY>`.
Everything goes through one unified job API.

### Create a task

`POST /api/v1/jobs/createTask`

```json
{ "model": "<model>", "input": { }, "callBackUrl": "optional webhook" }
```

Returns `{"code":200,"data":{"taskId":"task_..."}}`. Codes: 401 bad key,
402 out of credit, 422 validation, 501 generation failed.

### Poll a task

`GET /api/v1/jobs/recordInfo?taskId=<id>`

`data.state` is one of `waiting`, `queuing`, `generating`, `success`,
`fail`. On success, `data.resultJson` is a JSON **string**; parse it and
read `resultUrls`. On failure read `data.failCode` and `data.failMsg`.
`data.progress` and `data.creditsConsumed` are also returned.

### Host a file

`POST https://kieai.redpandaai.co/api/file-stream-upload`, multipart,
`Authorization: Bearer` as above. Note the host: the docs give
`api.kie.ai`, which returns 404 for this path. Verified live in September
2026, so re-check if uploads start failing. Fields: `file` (binary, required), `uploadPath` (required, no
leading or trailing slash), `fileName` (optional). The hosted URL comes
back as `data.downloadUrl`. Files are deleted after three days, so this
suits generation input, not published media.

### Models

`gpt-image-2-text-to-image`
- `prompt` string, 1 to 20000 chars, required
- `aspect_ratio` auto, 1:1, 3:2, 2:3, 4:3, 3:4, 5:4, 4:5, 16:9, 9:16,
  2:1, 1:2, 3:1, 1:3, 21:9, 9:21. Default auto
- `resolution` 1K, 2K, 4K. 1:1 cannot use 4K
- `background` transparent, opaque, auto. 1K only

`gpt-image-2-image-to-image`
- as above, plus `input_urls`, an array of up to 16 image URLs, required

`bytedance/seedance-2-5` is the current video model and the skill default.
- `prompt` string, up to 30000 chars, required
- `resolution` 480p, 720p (default), 1080p. No 4k on this model
- `aspect_ratio` 1:1, 4:3, 3:4, 16:9, 9:16, 21:9, adaptive (default)
- `duration` integer 4 to 30 seconds, or -1 for automatic, default 5
- `first_frame_url`, `last_frame_url` image URL or `asset://{assetId}`.
  `last_frame_url` cannot be sent alone; it needs `first_frame_url` too
- `reference_image_urls` up to 30, `reference_video_urls` up to 10,
  `reference_audio_urls` up to 10 of 2 to 30 seconds, 15MB each
- `generate_audio` boolean default true, `return_last_frame` default
  false, `output_format` mp4 or mov, `web_search`, `nsfw_checker`

`bytedance/seedance-2` is the previous generation.
- `prompt` 3 to 20000 chars, `duration` 4 to 15 seconds, default 5
- `resolution` 480p, 720p (default), 1080p, 4k. This model has 4k
- `aspect_ratio` 1:1, 4:3, 3:4, 16:9 (default), 9:16, 21:9, adaptive
- `first_frame_url`, `last_frame_url`, `reference_image_urls` up to 9,
  `reference_video_urls` and `reference_audio_urls` up to 3 each
- `generate_audio` boolean, default true

`bytedance/seedance-2-fast` is the cheap one, for proving a pipeline.
- `resolution` 480p or 720p only, `duration` 4 to 15 seconds
- same frame and reference fields as seedance-2

Docs: https://docs.kie.ai/market/bytedance/seedance-2 and
https://docs.kie.ai/market/gpt/gpt-image-2-text-to-image

## Zernio

Base URL `https://zernio.com/api/v1`, override with `ZERNIO_API_BASE`.
Auth header `Authorization: Bearer sk_<64 hex>`. The key is shown once at
creation; Zernio stores only its hash.

A profile groups social accounts, one per brand or client. Its id is a
24 character string in `_id`. Pass `profileId` to scope account listing,
connect, analytics and inbox calls.

### Endpoints used here

`GET /accounts` optionally `?profileId=<id>` lists connected accounts,
each with `_id`, `platform`, `username`, `active`.

`POST /media/presign` with `{"filename":"x.mp4","contentType":"video/mp4"}`
returns `uploadUrl` and `publicUrl`. `PUT` the bytes to `uploadUrl`, then
use `publicUrl` in the post. Cap is 5 GB per file. Accepts JPEG, PNG,
GIF, WebP, MP4, MPEG, MOV, AVI, WebM, M4V, and PDF for LinkedIn only.

`POST /posts`

```json
{
  "content": "caption text",
  "mediaItems": [{ "url": "https://...", "type": "video" }],
  "platforms": [{ "platform": "tiktok", "accountId": "24charid" }],
  "scheduledFor": "2026-10-01T12:00:00",
  "timezone": "Europe/London"
}
```

Timing is one of: `scheduledFor` plus `timezone` to schedule,
`publishNow: true` to send immediately, or neither to save a draft.
Every `mediaItems[].url` must be publicly reachable over HTTPS and
return the file itself. Google Drive and Dropbox share links return HTML
and will fail.

Platforms supported include Instagram, TikTok, YouTube, LinkedIn, X,
Facebook, Pinterest, Threads, Bluesky, Reddit, Snapchat, Telegram,
WhatsApp and Google Business Profile.

Docs: https://docs.zernio.com

## Postiz

Self-hosted alternative at https://github.com/gitroomhq/postiz-app. It
exposes its own public API with an `Authorization` header holding the key
from Settings, and endpoints for upload and for creating posts. Read its
docs at the time of use; the shape differs from Zernio, so the scripts
here do not target it.
