---
name: ad-video
description: Produce a short vertical ad video from a product brief and publish it to social accounts. Use when asked to make an ad, promo, reel, short, 9:16 video, product video or social video, to generate images or video with Kie.ai (GPT Image 2, Seedance 2.5), or to schedule and post content through Zernio or Postiz. Covers brief to script to stills to clips to caption to scheduled post.
---

# Ad Video

Turn a product brief into a 9:16 ad and put it in front of an audience.
The pipeline is: brief, script, stills, clips, caption, scheduled post.
Generation runs on Kie.ai. Distribution runs on Zernio, or on a
self-hosted Postiz if James prefers to own the stack.

## Before anything else

Run `scripts/check-setup.sh`. It creates the credentials file on first
run and tells you exactly which key is missing or rejected. Do not start
generating until it passes, because each failed job still costs credit.

Store a key with `printf %s "the-key" | scripts/set-key.sh KIE_API_KEY`,
which reads from stdin so the value never reaches the command line, shell
history or the process list, and never gets echoed back.

Credentials live in `~/.config/ad-video/env` with permissions 600. They
are never committed, never pasted into chat and never written into a
script. If a key does end up in a transcript, say so and tell James to
revoke it, rather than letting it stand. If a key is missing, say which one and where to get it, then
stop and wait. You cannot obtain these keys yourself; they need a signed
in browser and a payment method.

## Step 1: get the brief straight

You need five things before generating. Ask only for what is missing,
in one message, and infer the rest from context:

1. Product and the one promise it makes
2. Audience and the moment they are in
3. Offer or call to action
4. Look and feel, plus any brand colours or fonts
5. Reference images of the actual product, as HTTPS URLs

Without a real product image the ad will show an invented product. If
James has photos locally, upload them first with
`scripts/zernio.sh upload FILE`, which returns a public HTTPS URL that
Kie.ai can read.

## Step 2: write the script before you spend credit

Draft a shot list as text and show it. A 15 to 20 second vertical ad is
normally three or four shots of 4 to 6 seconds. For each shot write the
visual, the on screen line and the spoken line if any.

Hook in the first 1.5 seconds, single benefit in the middle, one clear
call to action at the end. Get agreement on the shot list first. Text is
free to change; a rendered clip is not.

## Step 3: stills

Generate a key still per shot, at 9:16, using the product references:

```bash
scripts/kie.sh image --prompt "..." --ratio 9:16 --resolution 2K \
  --ref "https://.../product-front.jpg" --out ./out/stills
```

With `--ref` this uses `gpt-image-2-image-to-image` so the real product
carries through. Without it, `gpt-image-2-text-to-image`. Review the
stills before moving on. A weak still makes a weak clip.

## Step 4: clips

Each still becomes the first frame of a Seedance clip:

```bash
scripts/kie.sh video --prompt "slow push in, product held to camera" \
  --ratio 9:16 --resolution 1080p --duration 5 \
  --first-frame "https://.../still-1.png" --out ./out/clips
```

The script polls until the job finishes and downloads the file. Jobs
take a few minutes. If one times out, the task id is printed; resume
with `scripts/kie.sh get TASK_ID --out ./out/clips`.

Prove the pipeline on the cheap model before committing credit to the
real render. `--model fast --resolution 480p --duration 4 --no-audio` is
the least expensive way to confirm a prompt behaves, then re-run the same
prompt at the settings you actually want.

Keep motion small and specific. Broad instructions produce drifting,
unusable footage. Audio is on by default; add `--no-audio` when you
plan to lay a voiceover or track over the top.

## Step 5: assemble

Kie.ai returns separate clips, not a finished cut. If ffmpeg is
available, concatenate them and report the final duration. If it is not,
say so plainly and hand over the individual clips in shot order with the
caption, rather than implying a finished edit exists.

## Step 6: caption and publish

Write the caption for the platform, not a generic one. Then:

```bash
scripts/zernio.sh accounts                    # find the account ids
scripts/zernio.sh post --content "..." --media ./out/final.mp4 \
  --platform tiktok:ACCOUNT_ID --dry-run
```

Publishing rules, which hold even when James has asked you to finish the
job end to end:

- Default to a draft. Omit `--now` and `--at` and the post is created as
  a draft in Zernio for a human to release.
- Use `--dry-run` first and show the exact payload.
- Only use `--now` or `--at` when James has approved that specific
  caption and cut in this conversation. A general instruction to build
  the pipeline is not approval to publish to his audience.

## Postiz as the alternative

Postiz (https://github.com/gitroomhq/postiz-app) is the open source,
self-hosted option covering the same ground as Zernio. It suits James if
he wants no per-post cost and full control, at the price of hosting it.
Zernio suits him if he wants it working today. Recommend Zernio to start
and Postiz once volume justifies the hosting. Do not run both.

## Paid distribution

Uploading a finished video into an ads manager is a separate job. It
needs a browser signed into that account, which these scripts do not
have. Produce the asset and the copy, then tell James it is ready to
upload, rather than claiming the campaign is live.

## Finished means

A named video file on disk, the caption text, and either a draft post
with its Zernio id or a clear statement of what is blocking. Report the
credit spent if the API returned it. Do not describe a queued job as a
delivered ad.

## Reference

`references/api.md` holds the exact endpoints, models, parameters and
response shapes for Kie.ai and Zernio. Read it before writing any custom
request rather than guessing field names.
