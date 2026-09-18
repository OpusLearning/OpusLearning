# TEST-CHECKLIST

Record the date, the image SHA-256 and the UART log filename for every run.
A stage is passed only when there is a log line that proves it, not when it
"seems to work".

## Before every boot

- [ ] Partition backups verified (`scripts/verify-backups.sh`), all 13 match
- [ ] UART attached, 1500000 8N1, capture running **before** power is applied
- [ ] SD image SHA-256 recorded and matches the manifest
- [ ] Confirmed the card contains no Rockchip update image
- [ ] Confirmed the DTB on the card has `&sdhci` disabled (`fdtget`/`dtc` check)

## Stage 0: diagnostic U-Boot card, no Android

- [ ] 0.1 UART shows a Rockchip loader banner
- [ ] 0.2 U-Boot from SD reaches an interactive prompt
- [ ] 0.3 `mmc list` output captured; eMMC and SD indices identified and recorded
- [ ] 0.4 `part list` for the eMMC shows the stock partition table, matching `by-name.txt`
- [ ] 0.5 No write command was issued at any point
- [ ] 0.6 Card removed, power cycle, stock Android 7.1.2 boots normally

Record which component performed the handover to SD. This settles A-03.

## Stage 2: first Android boot from SD

The ten success stages from the brief:

- [ ] 1. Rockchip BootROM/loader recognises the SD card
- [ ] 2. U-Boot starts from SD
- [ ] 3. Kernel starts
- [ ] 4. Android userspace starts
- [ ] 5. LVDS display works at the correct resolution and orientation
- [ ] 6. Touch works
- [ ] 7. Wi-Fi works
- [ ] 8. Audio works
- [ ] 9. Camera works
- [ ] 10. Power button and standby work

Note against each failure: the last UART line before the hang, and the change
made to the SD image in response. Changes go in the SD image only. Never in eMMC.

## After every boot, without exception

- [ ] Power off, remove the card, power on, stock Android 7.1.2 boots normally
- [ ] Over ADB on the stock system, hash the eMMC partitions read-only and
      compare against the backups. Any difference stops the project until
      understood.

That second check is the actual evidence for the project's central safety claim.
Doing it once is not enough; do it every time.

## Phase 7: application compatibility

Check DRM capability first, because it determines what is achievable:

- [ ] `dumpsys media.drm` captured; Widevine security level recorded (L1/L3/none)
- [ ] `getprop | grep -i widevine` captured

Then the applications:

- [ ] Firefox, current or near-current, installs and runs
- [ ] YouTube, playback at panel resolution, audio in sync
- [ ] Zoom, camera and microphone both functional in a real call
- [ ] Teams, same
- [ ] Apple Music, playback and account sign-in
- [ ] Play Store and Play Services functional (note: on stock Android 7 the Store
      had to be side-loaded at the version matching Play Services)

Record for each: version tested, works/partial/fails, and the specific symptom.

## Phase 7b: family dashboard / profile launcher

Assessed separately, once the above is stable. Do not let it influence the
platform decision; it is an application problem, not a boot problem.
