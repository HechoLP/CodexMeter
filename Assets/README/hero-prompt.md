# README hero

- Asset: `codexmeter-hero.png`.
- Mode: built-in `image_gen` image editing (not the CLI).
- Base: the previous README hero at commit `1408b66`.
- App reference: the user-provided Token Usage screenshot. The private source screenshot is intentionally not checked in.
- The existing branding and desktop composition are retained; the current popover is composited into the right side.
- The email and token figures are fictional presentation data, not account usage. The app's accounting and authentication data are unchanged.
- Example arithmetic: 24.2M input + 600K output = 24.8M total; 20.6M cached input is included in input, not added again.

## Final prompt

```text
Use case: compositing with precise text replacement.
Asset type: existing CodexMeter GitHub README hero, landscape approximately 16:9, high-resolution raster.

INPUT ROLES:
Image 1 is the EXISTING HERO to edit. Keep its framing, dark desktop background, macOS menu bar, large app icon on the left, large white "CodexMeter" headline, and lavender tagline "Local Codex token usage, one click away." unchanged in design and placement.
Image 2 is the ACTUAL NEW APP SCREENSHOT to insert. This is a screenshot replacement, not permission to invent a different UI.

PRIMARY EDIT:
Remove only the old app popover on the right of Image 1 and replace it with the entire newer popover from Image 2. Use the real screenshot's layout, SF-style typography, icons, sections, separators, colors, selected blue Token Usage tab, account switch row, three input/cached/output columns, History section, Usage/Projects/Sessions links and footer. Do not reuse the old UI or its numbers.
Fit the taller new popover proportionally inside the right third of the hero, roughly 25-27% of canvas width and around 80-84% of canvas height. Keep the ENTIRE panel visible, all footer actions visible, with comfortable margin below it and to the right. Do not stretch it or overlap the headline/tagline. Preserve the left-side brand composition. Match natural macOS floating-panel corners, subtle outline, glass/charcoal material and soft shadow to the base hero, not a harsh rectangular pasted screenshot. The source screenshot's rightmost edge is slightly cropped: complete only the missing edge/right padding so "This Mac", "ChatGPT · Through Aug 31", chevrons and "More" are fully legible; do not invent additional interface elements. A small top pointer can visually connect the panel to the existing menu-bar app icon as in the base.

PRIVACY / EXACT TEXT REPLACEMENTS IN THE NEW APP PANEL:
Replace the account email with exactly "alex@example.com".
Use exactly these fictional token figures in their original positions:
Today big total: "24.8M"
Input: "24.2M"
Cached input: "20.6M"
Output: "600K"
This Week: "128M"
This Month: "486M"
Lifetime: "2.14B"
These examples intentionally have total = input + output and cached input included within input. Do NOT retain any original email or original token values from either input image.

PRESERVE THESE PANEL LABELS AND ORDER:
"CodexMeter"
account row: "alex@example.com", "Switch"
tabs: "Token Usage", "Codex Limits"
"Today", "This Mac"
"24.8M"
"Input", "Cached input", "Output"
"24.2M", "20.6M", "600K"
"History", "ChatGPT · Through Aug 31"
"This Week" / "128M"
"This Month" / "486M"
"Lifetime" / "2.14B"
"Usage"
"Projects"
"Sessions"
"Account totals through Aug 31"
"Refresh", "Settings", "More"

CONSTRAINTS:
Keep all text crisp and readable. Preserve the identity of the actual app screenshot. No extra badges, cards, illustrations, watermarks or decoration. No private email. No original token values. No duplicated UI. No cropped panel. Natural and restrained compositing, matching the existing README hero, not a new promotional design. Render one edited landscape hero image.
```
