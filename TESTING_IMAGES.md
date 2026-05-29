# Testing Images Guide

This project reads import images from the iOS photo library (`PhotosPicker`).
If the Simulator has no photos, import tests will appear blocked.

## 1) Add images to iOS Simulator photo library

Use drag and drop:
1. Launch the Simulator and open your app.
2. Drag `jpg/png` files from Finder onto the Simulator window.
3. Open Photos app in Simulator to verify images exist.

Or use command line:
```bash
xcrun simctl addmedia booted /ABSOLUTE/PATH/image1.jpg /ABSOLUTE/PATH/image2.png
```

Import an entire folder:
```bash
xcrun simctl addmedia booted /ABSOLUTE/PATH/test-images
```

Then return to app and tap `Choose Tutorial Image`.

## 2) Find your app-saved images on disk

`AssetStore` writes to Application Support by default.

Inside Simulator container it is:
`.../Library/Application Support/CrochetStepAssistantAssets/<projectId>/...`

Quick way to open current app container:
```bash
xcrun simctl get_app_container booted com.your.bundle.id data
```

Then open the returned path in Finder.

## 3) Add stable fixture images for unit tests

Recommended folder in this repo:
`CrochetStepAssistantTests/Fixtures/`

In Xcode:
1. Right-click `CrochetStepAssistantTests` group.
2. Select `Add Files to "CrochetStepAssistant"...`.
3. Choose your fixture images.
4. Check target `CrochetStepAssistantTests`.
5. Keep `Copy items if needed` enabled.

This keeps test images deterministic and independent from Simulator Photos.

## 4) Use custom local file paths during development

If you need path-based debug tests, keep sample images in a local folder, then import with:
```bash
xcrun simctl addmedia booted /ABSOLUTE/PATH/to/local-images
```

The app itself cannot directly read arbitrary host machine paths from iOS sandbox.
Use Photos import (or bundle test fixtures) instead.
