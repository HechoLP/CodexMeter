---
name: CodexMeter
description: A quiet native instrument for Codex usage and account limits.
typography:
  primary-metric:
    fontFamily: "SF Pro Rounded, system-ui, sans-serif"
    fontSize: "32px"
    fontWeight: 600
rounded:
  detail-selection: "8px"
  detail-card: "10px"
spacing:
  compact: "4px"
  row: "8px"
  section: "12px"
  content: "16px"
  popover-edge: "18px"
components:
  overview-popover:
    width: "344px"
  limit-card:
    rounded: "{rounded.detail-card}"
    padding: "{spacing.section}"
  shortcut:
    height: "42px"
  footer-action:
    height: "28px"
    width: "28px"
---

# Design System: CodexMeter

## Overview

**Creative North Star: "The Quiet Instrument"**

CodexMeter should feel like a compact macOS instrument that is ready when opened and disappears when the user returns to work. It is precise, calm, and native: the first screen answers the immediate questions, while charts, projects, sessions, and full limit details remain one click deeper.

The product uses system materials, semantic labels, SF Symbols, hairline separators, and tabular numerals instead of decorative dashboard chrome. Density is intentional, but every section must have one clear purpose and retain enough spacing to scan quickly.

**Key Characteristics:**

- Native macOS controls and semantic system styling.
- Token totals remain the strongest visual signal.
- Progressive disclosure instead of one long provider dashboard.
- Quiet status communication with explicit text for warnings and estimates.
- Motion explains change and never blocks interaction.

## Colors

The palette follows macOS semantic colors so it remains correct in light, dark, increased-contrast, and accent-color configurations.

### Primary

- **System Accent:** Used for healthy progress and the current macOS selection accent. Its exact color belongs to the user's system configuration.

### Secondary

- **Warning Orange:** Used only when remaining quota is low or pace is above an even-use schedule.
- **Critical Red:** Used only when remaining quota is critical.

### Neutral

- **System Background:** The popover and destination surfaces use the platform background.
- **Primary, Secondary, Tertiary Labels:** Information hierarchy comes from semantic label roles rather than fixed gray values.
- **Quaternary Fill:** Detail cards use a restrained tonal fill, with dividers separating major overview sections.

**The Semantic Color Rule.** Do not replace native semantic colors with fixed light- or dark-mode values.

**The Text-With-Color Rule.** Warning and critical colors always appear with an explicit label such as “Low” or “Critical.”

## Typography

**Display Font:** SF Pro Rounded for the primary token total.
**Body Font:** The macOS system font through SwiftUI semantic text styles.
**Label/Mono Font:** Monospaced digits for token counts, percentages, and cost values.

**Character:** The hierarchy is compact and factual. The rounded headline gives the primary metric a recognizable but restrained identity; all supporting text follows native semantic sizing and Dynamic Type.

### Hierarchy

- **Primary Metric** (semibold, 32px): Today's total and the strongest number on the overview.
- **Headline** (semantic headline): Product title and primary empty-state messages.
- **Section Label** (semibold subheadline): Limits and analytic section headings.
- **Body Row** (semantic subheadline): Token components and period totals.
- **Supporting Label** (caption and caption2): Reset times, pace, data status, and explanatory text.

**The Number Stability Rule.** Use monospaced digits and numeric content transitions anywhere changing values could shift the layout.

## Layout

The menu popover is a fixed compact column (344px). The header and footer remain stable while the middle region scrolls up to 540px. Major overview sections use dividers; details use the same width so navigation never causes a horizontal jump.

The spacing rhythm is 4px for tightly related icon-label pairs, 8px for rows, 12px between components inside a section, 16px for detailed-screen content, and 18px at overview edges. The overview prioritizes today's local usage, then account limits, nearby periods, and three compact analytic shortcuts.

**The One-Question Rule.** Each destination answers one question: limits, usage, projects, or sessions.

**The Real-Provider Rule.** A provider switcher appears only after a second provider has working data and status handling; empty provider tabs are not navigation.

## Elevation & Depth

CodexMeter is flat by default. Depth comes from the native menu-bar window, semantic tonal fills in detail cards, dividers, and selection state—not decorative shadows, gradients, or glass effects added by the app.

**The Flat-By-Default Rule.** Use tonal grouping and system materials before introducing custom elevation.

## Shapes

The diamond meter mark is the only recurring branded silhouette. Detail selections use gently rounded 8px containers, while information cards use 10px corners. Standard buttons, progress views, menus, and navigation controls retain native macOS shapes.

**The Native Control Rule.** Do not redraw a platform control solely to mimic another menu-bar app.

## Components

### Overview Popover

- **Character:** A compact status instrument, not a miniature dashboard.
- **Shape:** Fixed 344px width with a stable header and footer.
- **Behavior:** The center scrolls only when content exceeds the practical menu height.

### Primary Token Summary

- **Character:** Immediate and auditable.
- **Content:** Total first, then Input, Cached input, and Output; help text explains that cached input is included in Input and Total equals Input plus Output.
- **Motion:** Numeric transitions use a short 0.2–0.24 second ease-out and are removed when Reduce Motion is enabled.

### Account Limit Preview

- **Character:** Actionable without pretending to be a billing dashboard.
- **Content:** At most two limit windows, percent remaining, reset countdown, and even-use pace; additional windows move to Limits.
- **State:** Healthy uses the system accent; low and critical states combine color with text.
- **Disclosure:** Projected run-out appears only in the detailed Limits screen and is labeled as an estimate.

### Analytic Shortcuts

- **Character:** Three equal one-click destinations for Usage, Projects, and Sessions.
- **Shape:** Each target is at least 42px high with an SF Symbol and visible label.
- **Behavior:** Hidden preferences remove their destination instead of leaving disabled placeholders.

### Footer Actions

- **Character:** Stable utility actions with 28px targets.
- **Behavior:** Refresh rotates once while starting and respects Reduce Motion; Settings and More remain fixed. More groups status, repository, update, and quit actions.
- **Keyboard:** Refresh uses Command-R, Settings uses Command-comma, and Quit uses Command-Q.

### Detail Cards

- **Character:** Quiet tonal containers for limit, selection, and breakdown details.
- **Shape:** 10px corners with 12px padding; selected chart details use 8px corners.
- **Background:** Quaternary semantic fill at low opacity.

## Do's and Don'ts

### Do:

- **Do** keep the first screen focused on current local usage, actionable account limits, nearby periods, and direct navigation.
- **Do** use semantic system colors, SwiftUI text styles, SF Symbols, VoiceOver labels, keyboard shortcuts, and Reduce Motion.
- **Do** show unknown or incomplete cost data as unavailable in detailed analytics instead of zero.
- **Do** keep local token totals, account-wide profile totals, quota percentages, and API-equivalent estimates visibly distinct.
- **Do** add Claude, Gemini, or another provider behind a shared provider boundary before exposing it in navigation.

### Don't:

- **Don't** copy CodexBar branding, assets, provider tab layout, or long single-page composition.
- **Don't** place charts, projects, sessions, credits, every provider, and every limit on the overview.
- **Don't** show empty or speculative provider tabs.
- **Don't** use purple/blue AI gradients, neon, decorative glass, giant cards, or custom dashboard chrome.
- **Don't** communicate low quota, stale data, or estimates through color alone.
