# GlucoseBar

**Glucose trends at a glance, in your Mac menu bar.**

A native macOS companion for the mainland China SiBionics app (硅基动感), currently tested with **GS1 + iPhone**. Your iPhone receives and uploads sensor readings; GlucoseBar reads your own cloud history. This is an independent, early testing project.

[中文说明](README.md) · [Privacy](PRIVACY.md) · [MIT License](LICENSE) · [Report an issue](https://github.com/zeqiulee/glucosebar/issues/new/choose)

![Menu bar display modes using synthetic data](docs/images/menu-bar-modes.png)

## Status and compatibility

- macOS 14+, Swift 6.0+; Chinese UI; mmol/L.
- Cloud access only. No direct Bluetooth or HealthKit integration.
- Other sensor models, countries, apps and account types are unverified.
- **No Developer ID signing or Apple notarization yet.** Source and explicitly labeled unnotarized test builds are for early evaluation. A build passing CI does not prove that another Mac can install it. Signed downloads will be announced after distribution and separate-machine testing are complete.
- Getting a login credential currently requires HTTPS debugging on your own iPhone. There is no one-click sign-in.

This app is a secondary display. It has no alarms and does not diagnose conditions or recommend treatment. Keep using the original app's alerts and check measurement timestamps. Cloud uploads can be delayed.

## Features

- Switch between a compact 12-hour menu bar trace and a white reading with a colored trend arrow.
- Expand 3 / 6 / 12 / 24-hour history and hover over actual measurements.
- Smooth, continuously colored traces; gaps longer than 10 minutes remain disconnected.
- Duration-based reference-range statistics, with coverage explained in the tooltip.
- Credentials in macOS Keychain; credential-bound local cache; no project server or analytics SDK.
- Synthetic demo mode without an account.

![History preview using synthetic data](docs/images/history.png)

The fixed **3.9–6.9 mmol/L** range is a display reference chosen by the original user, not a universal health target. The Chinese label “健康比例” means estimated time within this reference range divided by the **full selected window**. Missing time stays in the denominator, so inspect data coverage too. It is not a medical health score.

## Build locally

```sh
git clone https://github.com/zeqiulee/glucosebar.git
cd glucosebar
./scripts/test-core.sh
./scripts/build-app.sh ./dist
open ./dist/GlucoseBar.app
```

Set `GLUCOSEBAR_ARCH` to `arm64`, `x86_64` or `universal`. Cross-compilation is not hardware testing. Read the [Chinese setup guide](docs/getting-started.zh-CN.md) and [release guide](docs/releasing.zh-CN.md) for distribution limits.

## Feedback and privacy

Never attach a token, Authorization header, HAR file, cloud response, sensor identifier or personal glucose history to an issue. Provide app version, macOS version, chip and sanitized reproduction steps. See [CONTRIBUTING](CONTRIBUTING.md) and [SECURITY](SECURITY.md).

The cloud endpoint was independently implemented using public community research, including [nightscout-sisensingcgm-uploader](https://github.com/ImLovinIt/nightscout-sisensingcgm-uploader). No implementation code was copied from that project. GlucoseBar is not affiliated with or endorsed by SiBionics or Apple. The unofficial endpoint may change or stop working.

Released under the [MIT License](LICENSE), copyright © 2026 zeqiulee.
