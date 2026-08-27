using CodexMeter.Core.Domain;
using CodexMeter.Core.Services;
using System.Text.Json;

namespace CodexMeter.Core.Tests;

public sealed class UsageScannerTests
{
    [Fact]
    public async Task ExcludesInheritedReplayAndCountsFreshChildUsage()
    {
        var root = CreateTemporaryDirectory();
        try
        {
            var session = Path.Combine(root, "child.jsonl");
            await File.WriteAllLinesAsync(session,
            [
                "{\"timestamp\":\"2026-08-27T01:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"child\",\"parent_thread_id\":\"parent\",\"subagent_history_start_ordinal\":2}}",
                TokenLine("2026-08-27T01:00:01Z", 1, 100, 60, 20),
                TokenLine("2026-08-27T01:00:02Z", 2, 150, 90, 30),
                "{\"timestamp\":\"2026-08-27T01:00:03Z\",\"type\":\"event_msg\",\"ordinal\":3,\"payload\":{\"type\":\"task_started\",\"started_at\":1787792403}}",
                TokenLine("2026-08-27T01:00:04Z", 4, 180, 100, 40)
            ]);

            var scanner = new UsageScanner([root]);
            var result = await scanner.ScanAsync(WeekStart.Monday);

            Assert.Equal(new TokenUsage(30, 10, 10), result.Snapshot.AllTime);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task DeduplicatesAnArchivedSessionCopy()
    {
        var root = CreateTemporaryDirectory();
        try
        {
            var current = Path.Combine(root, "current.jsonl");
            var archived = Path.Combine(root, "archived.jsonl");
            var lines = new[]
            {
                "{\"timestamp\":\"2026-08-27T01:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"session-1\"}}",
                TokenLine("2026-08-27T01:00:01Z", 1, 100, 60, 20)
            };
            await File.WriteAllLinesAsync(current, lines);
            await File.WriteAllLinesAsync(archived, lines);

            var scanner = new UsageScanner([root]);
            var result = await scanner.ScanAsync(WeekStart.Monday);

            Assert.Equal(new TokenUsage(100, 60, 20), result.Snapshot.AllTime);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task SeedsButDoesNotCountAnOrdinalFreeParentReplay()
    {
        var root = CreateTemporaryDirectory();
        try
        {
            var session = Path.Combine(root, "fork.jsonl");
            await File.WriteAllLinesAsync(session,
            [
                "{\"timestamp\":\"2026-08-27T00:00:10Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"child\",\"forked_from_id\":\"parent\"}}",
                "{\"timestamp\":\"2026-08-27T00:00:10Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"parent\"}}",
                "{\"timestamp\":\"2026-08-27T00:00:10.001Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\",\"started_at\":1}}",
                TokenLineWithLast("2026-08-27T00:00:10.002Z", 5_000, 4_000, 500, 5_000, 4_000, 500),
                "{\"timestamp\":\"2026-08-27T00:00:10.100Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\",\"started_at\":4000000000}}",
                TokenLineWithLast("2026-08-27T00:00:20Z", 5_100, 4_080, 520, 100, 80, 20)
            ]);

            var scanner = new UsageScanner([root]);
            var result = await scanner.ScanAsync(WeekStart.Monday);

            Assert.Equal(new TokenUsage(100, 80, 20), result.Snapshot.AllTime);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task RetriesAnIncompleteFinalLineAfterAppend()
    {
        var root = CreateTemporaryDirectory();
        try
        {
            var session = Path.Combine(root, "growing.jsonl");
            var metadata = "{\"timestamp\":\"2026-08-27T01:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"growing\"}}";
            var first = TokenLineWithLast("2026-08-27T01:00:01Z", 100, 60, 20, 100, 60, 20, 1);
            var second = TokenLineWithLast("2026-08-27T01:00:02Z", 150, 90, 30, 50, 30, 10, 2);
            await File.WriteAllTextAsync(session, $"{metadata}\n{first}\n{second}");

            var scanner = new UsageScanner([root]);
            var beforeAppend = await scanner.ScanAsync(WeekStart.Monday);
            Assert.Equal(new TokenUsage(100, 60, 20), beforeAppend.Snapshot.AllTime);

            await File.AppendAllTextAsync(session, "\n");
            var afterAppend = await scanner.ScanAsync(WeekStart.Monday);
            Assert.Equal(new TokenUsage(150, 90, 30), afterAppend.Snapshot.AllTime);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    private static string CreateTemporaryDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), $"CodexMeterTests-{Guid.NewGuid():N}");
        Directory.CreateDirectory(path);
        return path;
    }

    private static string TokenLine(
        string timestamp,
        long ordinal,
        long input,
        long cached,
        long output) => TokenLineWithLast(
            timestamp,
            input,
            cached,
            output,
            input,
            cached,
            output,
            ordinal);

    private static string TokenLineWithLast(
        string timestamp,
        long input,
        long cached,
        long output,
        long lastInput,
        long lastCached,
        long lastOutput,
        long? ordinal = null) => JsonSerializer.Serialize(new
        {
            timestamp,
            type = "event_msg",
            ordinal,
            payload = new
            {
                type = "token_count",
                info = new
                {
                    total_token_usage = new
                    {
                        input_tokens = input,
                        cached_input_tokens = cached,
                        output_tokens = output
                    },
                    last_token_usage = new
                    {
                        input_tokens = lastInput,
                        cached_input_tokens = lastCached,
                        output_tokens = lastOutput
                    }
                }
            }
        });
}
