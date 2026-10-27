# Tipper

A small, fast tip calculator for iPhone, built with SwiftUI.

Type in the bill, pick a tip, and the tip and total update as you go. If you'd rather round the total up to an even number, type the total you want to pay and Tipper works backward to the tip and percentage.

Tipper runs entirely on the device. It has no network access, no accounts, no analytics, and no third-party dependencies, and it doesn't save anything you type.

## Features

- **Quick presets**: 18%, 20%, 22%, and 25%, one tap each.
- **Fine-grained slider**: any rate from 10% to 40%, in 0.1% steps.
- **Editable total**: type the total you want to pay and the tip and percentage are recalculated to match. If that puts the rate outside the slider's range, the exact rate is still shown and the slider thumb dims to show it's pinned at the end of the track.
- **Locale-aware currency**: uses the device's currency symbol, decimal separator, and minor units (two decimals for USD and EUR, none for JPY).
- **Totals that add up**: the tip is rounded to whole cents (or the local equivalent), so bill + tip always equals the total shown.
- **Clear button**: in the keyboard toolbar, resets everything.

## Requirements

- A Mac with **Xcode 26** or later
- **iOS 18.0** or later (iPhone)
- No package managers or dependencies

To run in the iOS Simulator you don't need an Apple Developer account.

## Getting started

### Run in the Simulator

```sh
git clone https://github.com/kdbdallas/Tipper.git
cd Tipper
open Tipper.xcodeproj
```

In Xcode, choose the **Tipper** scheme and any iPhone simulator, then press **⌘R**.

You can also build from the command line:

```sh
xcodebuild -project Tipper.xcodeproj \
  -scheme Tipper \
  -destination 'generic/platform=iOS Simulator' \
  build
```

### Run on your own iPhone

To install the app on a physical device, it has to be signed with your own Apple ID:

1. In Xcode, select the **Tipper** project in the navigator, then the **Tipper** target, then the **Signing & Capabilities** tab.
2. Set **Team** to your own team. A free Apple ID works for installing on your own devices.
3. Change **Bundle Identifier** from `com.port21.Tipper` to something unique to you, such as `com.yourname.Tipper`. Bundle identifiers must be unique across all of Apple, so the original one won't work under your team.
4. Connect your iPhone, select it as the run destination, and press **⌘R**.

The first time you do this, iOS may ask you to enable **Developer Mode** (Settings → Privacy & Security) and to trust your developer certificate (Settings → General → VPN & Device Management). Apps signed with a free Apple ID expire after 7 days. Run it from Xcode again to reinstall.

## Project structure

```
Tipper/
├── TipperApp.swift       App entry point
├── ContentView.swift     The entire UI and all of the tip math
└── Assets.xcassets       App icon and accent color
Tipper-PRIVACY.html       Privacy policy page
Tipper-ABOUT.html         About page and user guide
```

## How it works

The app is intentionally small: one view, no persistence, no external dependencies.

- **One source of truth for the tip.** `ContentView` keeps a single `TipBasis` value, which is either a *percentage* (set by the presets or slider) or an explicit *amount* (set by typing over the total). Every other number on screen is derived from it. That prevents the displayed rate and the displayed tip from drifting apart.
- **Editing the bill after editing the total** converts the explicit tip back into the rate it represented, so what you meant is kept rather than reset.
- **Input sanitizing.** `.decimalPad` will happily accept `12.5.0`, so amounts are cleaned as you type: digits only, at most one decimal separator, and no more decimal places than the local currency uses.
- **Custom slider.** `TipSlider` wraps `UISlider` because SwiftUI's `Slider` can't restyle its thumb, and the thumb is what dims when the real rate is outside the 10–40% track.

## Contributing

Bug reports and pull requests are welcome. Please open an issue first for anything larger than a small fix, so we can agree on the approach before you put time into it.

## License

Tipper is released under the [MIT License](LICENSE).
