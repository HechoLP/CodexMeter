using CodexMeter.Core.Domain;
using CodexMeter.Core.Parsing;
using CodexMeter.Core.Services;
using System.Text.Json;

namespace CodexMeter.Core.Tests;

public sealed class UsageScannerTests
{
    [Fact]
    public async Task ExcludesInheritedReplayAndCountsFreshChildUsage()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
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
            ], cancellationToken).ConfigureAwait(true);

            var scanner = new UsageScanner([root]);
            var result = await scanner.ScanAsync(WeekStart.Monday, cancellationToken).ConfigureAwait(true);

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
        var cancellationToken = TestContext.Current.CancellationToken;
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
            await File.WriteAllLinesAsync(current, lines, cancellationToken).ConfigureAwait(true);
            await File.WriteAllLinesAsync(archived, lines, cancellationToken).ConfigureAwait(true);

            var scanner = new UsageScanner([root]);
            var result = await scanner.ScanAsync(WeekStart.Monday, cancellationToken).ConfigureAwait(true);

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
        var cancellationToken = TestContext.Current.CancellationToken;
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
            ], cancellationToken).ConfigureAwait(true);

            var scanner = new UsageScanner([root]);
            var result = await scanner.ScanAsync(WeekStart.Monday, cancellationToken).ConfigureAwait(true);

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
        var cancellationToken = TestContext.Current.CancellationToken;
        var root = CreateTemporaryDirectory();
        try
        {
            var session = Path.Combine(root, "growing.jsonl");
            var metadata = "{\"timestamp\":\"2026-08-27T01:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"growing\"}}";
            var first = TokenLineWithLast("2026-08-27T01:00:01Z", 100, 60, 20, 100, 60, 20, 1);
            var second = TokenLineWithLast("2026-08-27T01:00:02Z", 150, 90, 30, 50, 30, 10, 2);
            await File.WriteAllTextAsync(session, $"{metadata}\n{first}\n{second}", cancellationToken).ConfigureAwait(true);

            var scanner = new UsageScanner([root]);
            var beforeAppend = await scanner.ScanAsync(WeekStart.Monday, cancellationToken).ConfigureAwait(true);
            Assert.Equal(new TokenUsage(100, 60, 20), beforeAppend.Snapshot.AllTime);
            Assert.Equal(DataQuality.Partial, beforeAppend.Snapshot.Quality);

            await File.AppendAllTextAsync(session, "\n", cancellationToken).ConfigureAwait(true);
            var afterAppend = await scanner.ScanAsync(WeekStart.Monday, cancellationToken).ConfigureAwait(true);
            Assert.Equal(new TokenUsage(150, 90, 30), afterAppend.Snapshot.AllTime);
            Assert.Equal(DataQuality.Exact, afterAppend.Snapshot.Quality);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task InvalidatingTheCacheReprocessesASameStampRewrite()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        var root = CreateTemporaryDirectory();
        try
        {
            var session = Path.Combine(root, "rewrite.jsonl");
            var metadata = "{\"timestamp\":\"2026-08-27T01:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"rewrite\"}}";
            var original = TokenLine("2026-08-27T01:00:01Z", 1, 100, 60, 20);
            var replacement = TokenLine("2026-08-27T01:00:01Z", 1, 200, 60, 20);
            Assert.Equal(original.Length, replacement.Length);
            await File.WriteAllTextAsync(session, $"{metadata}\n{original}\n", cancellationToken).ConfigureAwait(true);
            var timestamp = File.GetLastWriteTimeUtc(session);

            var scanner = new UsageScanner([root]);
            var beforeRewrite = await scanner.ScanAsync(WeekStart.Monday, cancellationToken).ConfigureAwait(true);
            Assert.Equal(new TokenUsage(100, 60, 20), beforeRewrite.Snapshot.AllTime);

            await File.WriteAllTextAsync(session, $"{metadata}\n{replacement}\n", cancellationToken).ConfigureAwait(true);
            File.SetLastWriteTimeUtc(session, timestamp);
            scanner.InvalidateCachedSources();
            var afterRewrite = await scanner.ScanAsync(WeekStart.Monday, cancellationToken).ConfigureAwait(true);

            Assert.Equal(new TokenUsage(200, 60, 20), afterRewrite.Snapshot.AllTime);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task UsesLocalCalendarBoundariesAndExcludesFutureEvents()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        var root = CreateTemporaryDirectory();
        try
        {
            var now = new DateTimeOffset(2026, 8, 27, 12, 0, 0, TimeSpan.Zero);
            var session = Path.Combine(root, "periods.jsonl");
            await File.WriteAllLinesAsync(session,
            [
                "{\"timestamp\":\"2026-08-23T01:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"periods\"}}",
                TokenLineWithLast("2026-08-23T01:00:01Z", 10, 5, 2, 10, 5, 2, 1),
                TokenLineWithLast("2026-08-24T01:00:01Z", 20, 10, 4, 10, 5, 2, 2),
                TokenLineWithLast("2026-08-27T01:00:01Z", 30, 15, 6, 10, 5, 2, 3),
                TokenLineWithLast("2026-08-28T01:00:01Z", 40, 20, 8, 10, 5, 2, 4)
            ], cancellationToken).ConfigureAwait(true);

            var scanner = new UsageScanner([root]);
            var monday = await scanner.ScanAsync(WeekStart.Monday, now, cancellationToken).ConfigureAwait(true);
            var sunday = await scanner.ScanAsync(WeekStart.Sunday, now, cancellationToken).ConfigureAwait(true);

            Assert.Equal(new TokenUsage(10, 5, 2), monday.Snapshot.Today);
            Assert.Equal(new TokenUsage(20, 10, 4), monday.Snapshot.Week);
            Assert.Equal(new TokenUsage(30, 15, 6), sunday.Snapshot.Week);
            Assert.Equal(new TokenUsage(30, 15, 6), monday.Snapshot.AllTime);
            Assert.Equal(
                new DateTimeOffset(2026, 8, 27, 1, 0, 1, TimeSpan.Zero),
                monday.Snapshot.UpdatedAt);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task DuplicateSourcesCannotBypassTheRawEventCacheLimit()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        var root = CreateTemporaryDirectory();
        try
        {
            var first = Path.Combine(root, "a.jsonl");
            var duplicate = Path.Combine(root, "b.jsonl");
            var lines = new[]
            {
                "{\"timestamp\":\"2026-08-27T01:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"bounded-cache\"}}",
                TokenLineWithLast("2026-08-27T01:00:01Z", 100, 60, 20, 100, 60, 20, 1),
                TokenLineWithLast("2026-08-27T01:00:02Z", 150, 90, 30, 50, 30, 10, 2)
            };
            await File.WriteAllLinesAsync(first, lines, cancellationToken).ConfigureAwait(true);
            await File.WriteAllLinesAsync(duplicate, lines, cancellationToken).ConfigureAwait(true);

            var scanner = new UsageScanner(
                [root],
                maximumSourceCount: 10,
                maximumEventCount: 2,
                maximumEventsPerSource: 2,
                maximumSourceBytes: 2 * 1024 * 1024,
                maximumBytesPerScan: 8 * 1024 * 1024,
                maximumScanDuration: TimeSpan.FromSeconds(5));
            var result = await scanner.ScanAsync(
                WeekStart.Monday,
                new DateTimeOffset(2026, 8, 27, 12, 0, 0, TimeSpan.Zero),
                cancellationToken).ConfigureAwait(true);

            Assert.Equal(new TokenUsage(150, 90, 30), result.Snapshot.AllTime);
            Assert.Equal(DataQuality.Partial, result.Snapshot.Quality);
            Assert.Equal("Local session data limit reached", result.StatusMessage);
            Assert.False(result.HasMoreWork);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task ScanByteBudgetContinuesWithoutReprocessingCachedSources()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        var root = CreateTemporaryDirectory();
        try
        {
            var first = Path.Combine(root, "a.jsonl");
            var second = Path.Combine(root, "b.jsonl");
            var filler = new string('x', 600_000);
            await File.WriteAllLinesAsync(first,
            [
                "{\"timestamp\":\"2026-08-27T01:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"budget-a\"}}",
                TokenLine("2026-08-27T01:00:01Z", 1, 100, 60, 20),
                filler
            ], cancellationToken).ConfigureAwait(true);
            await File.WriteAllLinesAsync(second,
            [
                "{\"timestamp\":\"2026-08-27T01:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"budget-b\"}}",
                TokenLine("2026-08-27T01:00:02Z", 1, 200, 120, 40),
                filler
            ], cancellationToken).ConfigureAwait(true);

            var minimumSourceBudget = CodexJsonlParser.MaximumLineBytes + 1L;
            var scanner = new UsageScanner(
                [root],
                maximumSourceCount: 10,
                maximumEventCount: 10,
                maximumEventsPerSource: 10,
                maximumSourceBytes: minimumSourceBudget,
                maximumBytesPerScan: minimumSourceBudget,
                maximumScanDuration: TimeSpan.FromSeconds(5));
            var now = new DateTimeOffset(2026, 8, 27, 12, 0, 0, TimeSpan.Zero);

            var firstPass = await scanner.ScanAsync(
                WeekStart.Monday,
                now,
                cancellationToken).ConfigureAwait(true);
            Assert.True(firstPass.HasMoreWork);
            Assert.Equal(new TokenUsage(100, 60, 20), firstPass.Snapshot.AllTime);
            Assert.Equal("Importing local history…", firstPass.StatusMessage);

            var completed = await scanner.ScanAsync(
                WeekStart.Monday,
                now,
                cancellationToken).ConfigureAwait(true);
            Assert.False(completed.HasMoreWork);
            Assert.Equal(new TokenUsage(300, 180, 60), completed.Snapshot.AllTime);
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
