# CrochetHelper

CrochetHelper is a SwiftUI iOS app for importing crochet pattern instructions from images or text, splitting them into subprojects, editing the parsed structure, and following each row with a large mobile-first stitch counter.

The app is designed for long crochet / knitting counting sessions where clear progress, large touch targets, color guidance, and automatic state recovery matter.

## Features

- Import crochet instructions from Photos using OCR.
- Manually paste or type pattern text.
- Split one import into multiple subprojects.
- Review and edit parsed rows before saving.
- Expand row ranges such as `R6-R38: 30X` into individual rows.
- Merge continuation lines so wrapped instructions stay in one row.
- Calculate and display row stitch totals when possible.
- Create persistent projects and subprojects with SwiftData.
- Customize project title, cover image, cropped cover preview, and primary color.
- Customize subproject color, with project-color inheritance.
- Customize segment colors inside structure editing.
- Execute subprojects with a mobile-first counter page.
- Persist row, segment, and partial count progress after closing the app.
- Reset progress at row, subproject, or whole-project level.
- Toast messages for save, OCR, reset, and completion feedback.

## App Flow

1. Create or import a project from the home page.
2. Choose an image or enter text manually.
3. Review the detected subprojects.
4. Edit each subproject structure if needed.
5. Save the project.
6. Open a project card and choose a subproject.
7. Tap Play to continue counting from the last saved state.

## Import Text Format

Subprojects are separated by one or more empty lines.

Each subproject block uses:

- First non-empty line: subproject title.
- Remaining lines: crochet rows / steps.

Example:

```text
Ear
R1: 6X
R2: 6V
R3-R5: 12X

Body
R1: 8X
R2: 8V
R3: 8(X,W)
```

This creates two subprojects: `Ear` and `Body`.

## Supported Parsing Behavior

Range rows are expanded:

```text
R6-R8: 30X
```

becomes:

```text
R6: 30X
R7: 30X
R8: 30X
```

Continuation lines are joined to the previous row. For example:

```text
R43: 10X,2T,37W,2T,20X,2T,3TW
2T,10X
```

is treated as one `R43` instruction.

## Counter Page

The execution page focuses on one-handed use:

- Large current row header.
- Large current segment card.
- Minus and Done buttons.
- Big tappable segment area for repeated counting.
- Current row segment overview.
- Segmented row progress indicator.
- Previous Row and Complete Row controls.
- Automatic save after each interaction.
- Automatic completion message and return to the subproject list after the last stitch.

Color priority on the counter page:

1. Segment color.
2. Subproject color.
3. Project primary color.

## Project Structure

```text
CrochetStepAssistant/
  Assets/              Asset storage helpers
  Domain/              Codable project package and crochet models
  Features/
    Execution/         Row and segment counter UI
    Import/            Image import and OCR flow
    ProjectHome/       Project cards, subproject list, editing, persistence actions
    Review/            Import review and structure editing
  OCR/                 Vision OCR service
  Parsing/             Crochet tokenizer and parser
  Persistence/         SwiftData storage models and repository
CrochetStepAssistantTests/
  Unit tests for assets, domain, OCR, parsing, and persistence
TESTING_IMAGES.md      Simulator image import guide
scripts/               Development helper scripts
```

## Requirements

- Xcode 16 or newer recommended.
- iOS 17.0 or newer deployment target.
- iPhone Simulator or physical iPhone.
- Photos access for image import.

The project has been tested with an iPhone 17 Pro simulator target.

## Build

Open the project in Xcode:

```bash
open CrochetStepAssistant.xcodeproj
```

Or build from the command line:

```bash
xcodebuild \
  -project CrochetStepAssistant.xcodeproj \
  -scheme CrochetStepAssistant \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  build
```

If your simulator name or OS version is different, replace the `-destination` value with one available on your machine.

## Testing Images in Simulator

The app imports images from the iOS photo library. To add images to the simulator:

```bash
xcrun simctl addmedia booted /ABSOLUTE/PATH/image.png
```

Or drag image files directly onto the Simulator window.

More details are in [`TESTING_IMAGES.md`](TESTING_IMAGES.md).

## Documentation

The current product design and implementation summary is kept in:

- [`docs/superpowers/specs/2026-05-27-crochet-step-assistant-design.md`](docs/superpowers/specs/2026-05-27-crochet-step-assistant-design.md)

## Development Notes

This app currently stores projects locally with SwiftData. It does not require a backend service. OCR is handled on-device through Apple's Vision framework.

