# CodexMeter

CodexMeter is a native macOS menu bar utility that calculates locally observable Codex token usage from session history on the current Mac.

> Status: active development. No public release has been published yet.

## Planned release scope

- Today, week, month, and locally observable all-time totals
- Input, cached input, output, and total token breakdowns
- Incremental local JSONL ingestion with SQLite checkpoints
- Native menu bar and Settings interfaces
- No telemetry, analytics, cloud sync, or notifications

## Accuracy boundary

CodexMeter does not use an official account-usage API. “All Time” means the oldest token record available in local Codex session history through now. Deleted logs and usage performed on other Macs may not be represented.

Cached input is reported separately but is not added to total a second time. In the currently observed Codex event schema, total tokens equal input tokens plus output tokens, and cached input is a subset of input. Codex token-count events are cumulative snapshots, so CodexMeter derives component-wise increases and ignores repeated snapshots instead of summing every event.

## Privacy

CodexMeter is designed to read only the metadata needed for token accounting. It does not store prompts, responses, source code, terminal output, or authentication tokens, and it performs no telemetry or analytics.

## Development requirements

- macOS 14 or later
- Xcode 16 or later with Swift 6

```bash
swift test
swift run CodexMeter
```

Release packaging and verification instructions will be added with the first release candidate.

## Trademark

CodexMeter is an unofficial utility and is not affiliated with or endorsed by OpenAI.

## License

MIT. See [LICENSE](LICENSE).
