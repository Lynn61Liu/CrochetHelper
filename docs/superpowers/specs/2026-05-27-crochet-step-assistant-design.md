# Crochet Step Assistant Design

Last updated: 2026-05-29

## Purpose

Crochet Step Assistant helps users import crochet pattern instructions from images or text, split them into reusable subprojects, review and edit the parsed structure, then execute each subproject with a mobile-first row and segment counter.

The product is optimized for:

- Mobile-first use on iPhone Simulator and real iPhone.
- Long repetitive counting sessions.
- Clear project and subproject organization.
- Persistent progress after closing and reopening the app.
- Visual color support for projects, subprojects, rows, and segments.

## Core Concepts

### Project

A project represents one crochet work item. A project has:

- Title.
- Cover image or default icon.
- Primary color.
- Progress.
- One or more subprojects.
- Persistent package data stored in SwiftData.

The home page shows each project as a card. The `Play` button is the primary action and opens the subproject list.

### Subproject

A subproject represents one crochet part, such as an ear, body, leg, tail, or accessory.

Each subproject has:

- Title.
- Optional primary color.
- Parsed rows / steps.
- Per-segment colors.
- Independent execution progress.

If a subproject color is empty, it inherits the project primary color.

### Row / Step

A row is stored as `PatternStep`.

Each row has:

- Round label, such as `R1`, `R2`, `R43`.
- Raw instruction.
- Normalized instruction.
- Action segments.
- Optional stitch count target.

### Segment

A segment is stored as `ActionSegment`.

Each segment has:

- Source text, such as `12X` or `8(X,V)`.
- Action type.
- Count.
- Repeat count.
- Optional yarn color.

Segment color has the highest display priority in execution.

## Import Flow

### Initial Project Import

The user starts from the home page plus button.

Flow:

1. Open `ImportCropView`.
2. Select an image from Photos or use recognized/imported text.
3. OCR runs after image selection.
4. Extracted text appears in a text editor.
5. The user taps `Review Parsed Steps`.
6. The app shows a subproject summary page.
7. The user reviews each subproject structure.
8. The user taps `Create Project`.
9. The app persists the project and returns to the home page.

Before project creation, execution is not allowed. The import-time structure page hides `Start Execution`.

### Subproject Split Rules

Current split rule:

- Empty line, including one or more empty lines, separates subprojects.
- Each block's first non-empty line is the subproject title.
- Remaining lines are that subproject's steps.

Example:

```text
Ear
R1: 6X
R2: 6V

Body
R1: 8X
R2-R4: 8X
```

This creates two subprojects: `Ear` and `Body`.

### Add Subproject Flow

Inside an existing project's subproject list, the user can tap `Add Subproject`.

Supported input modes:

- Choose image and OCR.
- Manually input text.

The same split rules are used. One input can create one or many subprojects. Saving appends all parsed subprojects to the current project and refreshes the subproject list.

## Parsing Rules

### Range Expansion

Rows like:

```text
R6-R38: 30X
```

expand to independent rows:

```text
R6: 30X
R7: 30X
...
R38: 30X
```

Each expanded row is individually displayed and editable.

### Continuation Lines

If a line does not start with a row marker such as `R43`, it is treated as a continuation of the previous row.

This prevents cases like:

```text
R43: 10X,2T,37W,2T,20X,2T,3TW
2T,10X
```

from being split into two separate rows.

### Stitch Count

The app computes and displays row totals when possible.

Examples:

- `R1: 8X` => `8`
- `R2: 8V` => `16`
- `R3: 8(X,W)` => `24`

If an explicit trailing total exists, such as `(24)`, it is used first.

## Project Home

The home page uses a card layout inspired by craft pattern cards.

Each card includes:

- Project title.
- Progress indicator.
- Large cover image or default icon.
- Project details, including subproject count and row count.
- Reset project button.
- Primary `Play` button.
- Edit and delete icons.

### Project Edit

Project edit supports:

- Title editing.
- Cover image selection from Photos.
- Cover crop preview.
- Drag-to-position.
- Pinch-to-zoom.
- Reset crop.
- Primary color selection.

Saving writes the cropped cover image into `StoredProject.coverImageData`.

### Project Delete

Deleting a project shows a destructive confirmation alert and removes the persisted SwiftData record.

### Project Reset

Resetting a project clears execution progress while keeping the project, cover image, colors, subprojects, and steps.

It clears:

- `executionState`
- `executionStatesByComponentId`
- `progress`
- `project.currentStepIndex`
- project and component completion states
- home card progress

## Subproject List

The project `Play` button opens the subproject list.

Each subproject card includes:

- Title.
- Color indicator.
- Step count.
- Progress bar.
- Play button.
- Edit button.
- Delete button.
- Reset subproject button.

### Subproject Edit

Edit opens the structure page.

The structure page supports:

- Title editing.
- `Use project color` toggle.
- Subproject color picker when not inheriting project color.
- Row-by-row editing.
- Segment-level color editing.
- Saving all changes back into the project package.

### Subproject Delete

Deleting a subproject removes:

- The `PatternComponent`.
- All steps for that component.
- The component id from `project.componentOrder`.

Remaining subproject display order is normalized.

### Subproject Reset

Resetting a subproject clears only that subproject's progress.

It removes:

- `executionStatesByComponentId[componentId]`
- global `executionState` if it points to that component
- completed step ids for that component
- completed component id for that component

It does not delete rows, segment colors, or subproject color.

## Color System

Color inheritance is:

```text
segment color > subproject color > project primary color
```

### Project Color

Stored on `StoredProject.primaryColorHex`.

Used by:

- Project card.
- Default subproject color.
- Execution fallback color.

### Subproject Color

Stored on `PatternComponent.primaryColorHex`.

If `nil`, the subproject uses project primary color.

The structure edit page exposes:

- `Use project color` toggle.
- Subproject color picker.

### Segment Color

Stored on `ActionSegment.yarnColorHex`.

It has highest priority in execution UI. Each segment can override the subproject and project colors.

## Execution Counter

The execution page is a mobile-first crochet / knitting counter.

Design goals:

- Minimal.
- Large touch targets.
- Single-hand friendly.
- Strong visual hierarchy.
- Current segment highly visible.
- Comfortable for repeated tapping.
- iOS-style rounded cards and soft shadows.

### Execution Layout

The page contains:

- Header with row capsule, row label, and total stitches.
- Current segment action card.
- Segment overview strip.
- Row progress area.
- Bottom row controls.
- Fixed bottom row switcher.

### Segment Interactions

Each segment has:

- Label.
- Target count.
- Current count.
- Completed state.

Interactions:

- Tapping the large segment target increments current count.
- Minus decrements current count, minimum `0`.
- Done completes the current segment.
- When current count reaches target, the app advances to the next segment.
- Completing the last segment completes the row.

### Row Reset

Execution page includes `Reset Row`.

It clears only the current row's segment counts and removes the current row from completed steps.

### Progress Persistence

Execution progress is saved after counter state changes.

The package stores:

- `executionState` as the latest active state.
- `executionStatesByComponentId` for independent per-subproject progress.
- `progress` for compatibility with existing progress displays.

This prevents progress for one subproject from overwriting another subproject's progress.

## Persistence

SwiftData stores `StoredProject`.

`StoredProject` contains:

- Project id.
- Name.
- Encoded `CrochetProjectPackage`.
- Updated timestamp.
- Primary color.
- Cover icon name.
- Cover image data.
- Completion progress.

`CrochetProjectPackage` is the main portable package model. It contains:

- Project metadata.
- Source patterns.
- Components/subprojects.
- Steps.
- Assets.
- Legacy progress.
- Latest execution state.
- Per-component execution states.

The package has custom decoding for forward compatibility. Missing newer fields decode to safe defaults instead of making older saved projects unreadable.

## Current Implementation Notes

Implemented in this session:

- Simulator image testing guide and helper script.
- OCR trigger after `PhotosPicker` selection.
- Project import and subproject summary flow.
- Empty-line-based subproject splitting.
- Range row expansion.
- Continuation-line merge.
- Stitch count display.
- Project creation and persistence.
- Project home card UI.
- Project edit, delete, reset.
- Cover image crop preview.
- Subproject list, edit, delete, reset.
- Add subproject from image or manual text.
- Multi-subproject append inside existing project.
- Structure editing for rows and segments.
- Color inheritance and segment color overrides.
- Mobile-first execution counter UI.
- Per-subproject execution progress persistence.
- Global toast feedback.

## Open Questions / Future Work

- Execution page can be further refined after hands-on testing with real patterns.
- Segment parsing for complex crochet notation may need a more formal grammar.
- Color selection UX could add named yarn colors or palette presets.
- Cover crop could support multiple aspect ratios if future card layouts need non-square output.
- Project and subproject progress could become more precise by combining row completion and segment completion ratios.
- Tests should be added for package compatibility, multi-subproject import, color inheritance, and execution-state persistence.

## Verification

Recent local verification command:

```bash
xcodebuild -project CrochetStepAssistant.xcodeproj -scheme CrochetStepAssistant -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build
```

Recent result:

```text
BUILD SUCCEEDED
```
