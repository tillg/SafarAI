# History Design

Improvements to the event timeline display.

## Date and Time Display

- **Absolute time** shown for each event (e.g., "14:32") instead of relative time
- **Day separators** inserted between events from different days:
  - "Today" / "Yesterday" for recent dates
  - "Sat 23.1.2026" format for older dates

## SF Symbol Icons

Replaced emoji icons with SF Symbols using a two-symbol approach (base + direction indicator):

| Event Type | Base Symbol | Direction |
|------------|-------------|-----------|
| AI Query/Response | `brain` | `arrow.right` / `arrow.left` |
| Tool Call/Result | `wrench.and.screwdriver` | `arrow.right` / `arrow.left` |
| Tool Error | `wrench.and.screwdriver` | `exclamationmark.triangle` |
| Tab Open/Close | `safari` | `plus` / `minus` |
| Tab Switch | `safari` | `arrow.left.arrow.right` |
| Page Loaded | `safari` | `arrow.counterclockwise` |
| Link Click | `arrow.up.right.square` | — |

Icons are color-coded: purple (AI), orange (tools), blue (browser).

## Resizable Event Pane

The event timeline pane is now width-adjustable via a draggable divider (150px–500px range).

## Files Changed

- `BrowserEvent.swift` — `icon()` returns `(base: String, direction: String?)` tuple
- `EventCardView.swift` — Added `EventIconView` for two-symbol rendering
- `EventTimelineView.swift` — Added `DaySeparatorView` and day grouping
- `EventTimelineHelpers.swift` — Extracted testable helper functions
- `ContentView.swift` — Added `ResizableDivider` for adjustable pane width
