# Claude Code

Choose **Claude Code** in the menu's service selector. No login connection, API key, or change to Claude settings is required. This feature is in the current source build; previously published releases do not gain it until updated.

## Included

- Today, This Week, This Month, and Local History totals on this Mac.
- Input, cached input, and output; Today/7D/30D charts and model/project/session details.
- Local sub-agent transcripts, counted once per response and linked to their parent where the transcript identifies it.
- Automatic file-event refresh with the existing polling fallback, manual refresh, restart-safe imports, and separate history maintenance.

The default source is `~/.claude/projects/**/*.jsonl`. `CLAUDE_CONFIG_DIR` is honored when present as an absolute path in **CodexMeter's process environment**, with `/projects` appended. A shell-only environment setting does not automatically reach apps launched from Finder. Logs outside this root, deleted transcripts, Claude web/mobile chats, remote devices, and sessions with persistence disabled are not observable here.

## Menu presentation

The native service picker switches between Codex and Claude Code. Menu bar totals, Today, history, Usage/Projects/Sessions, and Settings data actions follow the selected service. Changing service returns the menu to its overview. Codex Limits, profile totals, and account switching remain Codex-only.

Claude inherits the existing 372pt macOS menu, semantic colors, system typography, keyboard controls, and Reduce Motion behavior. The service picker has a VoiceOver label, and analytics shortcut hints name the selected provider. With no local Claude usage, the menu prompts “Start a Claude Code session, then Refresh.” and hides history rows until a usage snapshot exists, rather than presenting missing history as zero.

## Accounting

Claude reports uncached `input_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`, and `output_tokens` separately. CodexMeter normalizes them as:

```text
Input        = input_tokens + cache_read_input_tokens + cache_creation_input_tokens
Cached input = cache_read_input_tokens (already included in Input)
Total        = Input + output_tokens
```

Cache TTL breakdowns, thinking/output details, and iteration details are not added again. Only valid assistant usage records with a stable message ID, recognized Claude model ID, and timestamp are accepted. API error/synthetic rows and malformed counters are excluded.

One API response can appear in multiple text/tool blocks or copied history. Its hashed message ID is the event identity across files. Repeated usage snapshots are not summed; increasing streaming counters update the maxima of the four disjoint components. The earliest observed timestamp owns the calendar day. Periods use the Mac's time zone and configured week start. Codex retains its separate cumulative-counter normalizer.

## Boundaries

Claude data lives in `Claude.sqlite`, alongside but separate from the existing `CodexMeter.sqlite`. It is not mixed with local Codex usage or ChatGPT profile totals. Clear/rebuild applies only to the service named in Settings; original transcripts remain untouched.

Clearing Claude history retains only the hashed identities of excluded responses in `claude_message_exclusions`, alongside the cutoff. This prevents later streaming blocks or copied transcripts from restoring a cleared response, including after a restart or rebuild. No cleared token counts, message contents, or raw identifiers are retained in that exclusion table. The additive table is created only for Claude imports; the Codex database schema is unchanged.

Claude account limits, web/mobile account-wide totals, account switching, attachment counts, and API-equivalent cost estimates are **not supported in this version**. An unknown price is unavailable, never a zero-cost claim. No Claude credential or settings file is read or changed.

## Verification

`swift test --filter ClaudeUsageTests` covers cache arithmetic, duplicate blocks, copied history, streaming revisions, restarts, local-day/week/month boundaries, analytics reconciliation, sub-agents, partial lines, rewrites, history cutoffs, and source isolation. An opt-in independent-accounting test accepts a temporary redacted numeric projection; no private transcript belongs in the repository.

Official references: [Claude Code session storage](https://code.claude.com/docs/en/sessions) and [Claude prompt-cache usage fields](https://platform.claude.com/docs/en/build-with-claude/prompt-caching). Transcript formats can change; unknown records are not guessed.
