using System.Buffers;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using CodexMeter.Core.Domain;
using CodexMeter.Core.Parsing;

namespace CodexMeter.Core.Services;

public sealed class UsageScanner
{
    public const int MaximumSourceCount = 50_000;
    public const int MaximumEventCount = 5_000_000;
    public const int MaximumEventsPerSource = 500_000;

    private readonly IReadOnlyList<string> roots;
    private readonly Dictionary<string, CachedFile> cache = new(StringComparer.OrdinalIgnoreCase);
    private int invalidationGeneration;
    private int appliedInvalidationGeneration;

    public UsageScanner(IEnumerable<string>? roots = null)
    {
        this.roots = (roots ?? DefaultRoots()).Select(Path.GetFullPath).ToArray();
    }

    public static IReadOnlyList<string> DefaultRoots()
    {
        var profile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var codex = Path.Combine(profile, ".codex");
        return
        [
            Path.Combine(codex, "sessions"),
            Path.Combine(codex, "archived_sessions")
        ];
    }

    public Task<ScanResult> ScanAsync(
        WeekStart weekStart,
        CancellationToken cancellationToken = default) =>
        Task.Run(() => Scan(weekStart, DateTimeOffset.Now, cancellationToken), cancellationToken);

    internal Task<ScanResult> ScanAsync(
        WeekStart weekStart,
        DateTimeOffset now,
        CancellationToken cancellationToken = default) =>
        Task.Run(() => Scan(weekStart, now, cancellationToken), cancellationToken);

    public void InvalidateCachedSources() => Interlocked.Increment(ref invalidationGeneration);

    internal ScanResult Scan(
        WeekStart weekStart,
        DateTimeOffset now,
        CancellationToken cancellationToken = default)
    {
        var currentInvalidationGeneration = Volatile.Read(ref invalidationGeneration);
        if (currentInvalidationGeneration != appliedInvalidationGeneration)
        {
            cache.Clear();
            appliedInvalidationGeneration = currentInvalidationGeneration;
        }

        var sources = DiscoverSources(cancellationToken);
        var activePaths = new HashSet<string>(sources, StringComparer.OrdinalIgnoreCase);
        var partial = false;

        foreach (var stale in cache.Keys.Where(path => !activePaths.Contains(path)).ToArray())
        {
            cache.Remove(stale);
        }

        foreach (var source in sources)
        {
            cancellationToken.ThrowIfCancellationRequested();
            try
            {
                var before = FileStamp.Read(source);
                if (cache.TryGetValue(source, out var cached) && cached.Stamp == before)
                {
                    partial |= cached.Partial;
                    continue;
                }

                var parsed = ParseFile(source, cancellationToken);
                var after = FileStamp.Read(source);
                if (before != after)
                {
                    cache.Remove(source);
                    partial = true;
                    continue;
                }

                cache[source] = new CachedFile(after, parsed.Events, parsed.Partial);
                partial |= parsed.Partial;
            }
            catch (Exception error) when (error is IOException
                                          or UnauthorizedAccessException
                                          or System.Security.SecurityException)
            {
                cache.Remove(source);
                partial = true;
            }
        }

        var events = new List<UsageEvent>();
        var eventKeys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var cached in cache.Values)
        {
            foreach (var usageEvent in cached.Events)
            {
                if (!eventKeys.Add(usageEvent.EventKey))
                {
                    continue;
                }

                if (events.Count >= MaximumEventCount)
                {
                    throw new InvalidOperationException(
                        $"More than {MaximumEventCount:N0} normalized token events were found.");
                }

                events.Add(usageEvent);
            }
        }

        var snapshot = Aggregate(events, now, weekStart, partial);
        var status = snapshot.Quality switch
        {
            DataQuality.Exact => snapshot.UpdatedAt is null ? "No Codex usage found" : "Updated just now",
            DataQuality.Partial => "Some history is incomplete",
            DataQuality.Unavailable => sources.Count == 0 ? "Codex sessions not found" : "No Codex usage found",
            _ => "Unable to read local usage"
        };
        return new ScanResult(snapshot, sources.Count, status);
    }

    private List<string> DiscoverSources(CancellationToken cancellationToken)
    {
        var sources = new List<string>();
        var options = new EnumerationOptions
        {
            RecurseSubdirectories = true,
            IgnoreInaccessible = true,
            AttributesToSkip = FileAttributes.Hidden
                | FileAttributes.System
                | FileAttributes.ReparsePoint,
            MatchCasing = MatchCasing.CaseInsensitive,
            MaxRecursionDepth = 64,
            ReturnSpecialDirectories = false
        };

        foreach (var root in roots)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!Directory.Exists(root))
            {
                continue;
            }

            var rootPrefix = Path.TrimEndingDirectorySeparator(root) + Path.DirectorySeparatorChar;
            foreach (var candidate in Directory.EnumerateFiles(root, "*.jsonl", options))
            {
                cancellationToken.ThrowIfCancellationRequested();
                var fullPath = Path.GetFullPath(candidate);
                if (!fullPath.StartsWith(rootPrefix, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                if (sources.Count >= MaximumSourceCount)
                {
                    throw new InvalidOperationException(
                        $"More than {MaximumSourceCount:N0} Codex session files were found.");
                }

                sources.Add(fullPath);
            }
        }

        sources.Sort(StringComparer.OrdinalIgnoreCase);
        return sources;
    }

    private static ParsedFile ParseFile(string path, CancellationToken cancellationToken)
    {
        var events = new List<UsageEvent>();
        var partial = false;
        var sessionId = HashIdentifier(SessionIdentifierFromFilename(path) ?? path);
        var state = UsageNormalizationState.Empty;
        var inheritsHistory = false;
        var historyReplayComplete = true;
        long? inheritedHistoryEndOrdinal = null;
        DateTimeOffset? sessionStartedAt = null;
        var sawSessionMetadata = false;

        using var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.ReadWrite | FileShare.Delete,
            bufferSize: 64 * 1024,
            FileOptions.SequentialScan);

        foreach (var boundedLine in BoundedLineReader.Read(stream, cancellationToken))
        {
            if (boundedLine.Oversized)
            {
                partial = true;
                continue;
            }

            var line = boundedLine.Bytes!;
            if (!ContainsRelevantMarker(line))
            {
                continue;
            }

            var parsed = CodexJsonlParser.Parse(line);
            switch (parsed.Kind)
            {
                case ParsedLineKind.SessionMetadata:
                    if (sawSessionMetadata)
                    {
                        if (inheritsHistory)
                        {
                            historyReplayComplete = false;
                        }
                        break;
                    }

                    sawSessionMetadata = true;
                    var metadata = parsed.SessionMetadata!;
                    if (metadata.Id is not null)
                    {
                        sessionId = HashIdentifier(metadata.Id);
                    }

                    inheritsHistory = metadata.InheritsHistory;
                    sessionStartedAt = metadata.OccurredAt;
                    inheritedHistoryEndOrdinal = metadata.SubagentHistoryStartOrdinal;
                    historyReplayComplete = metadata.SubagentHistoryStartOrdinal is null;
                    break;

                case ParsedLineKind.TaskStarted:
                    if (!inheritsHistory || historyReplayComplete)
                    {
                        break;
                    }

                    var task = parsed.TaskStarted!;
                    if (inheritedHistoryEndOrdinal is not null
                        && task.Ordinal is not null
                        && task.Ordinal.Value > inheritedHistoryEndOrdinal.Value)
                    {
                        historyReplayComplete = true;
                    }
                    else if (inheritedHistoryEndOrdinal is null
                             && sessionStartedAt is not null
                             && task.StartedAt is not null
                             && Math.Floor(task.StartedAt.Value.ToUnixTimeMilliseconds() / 1000d)
                             >= Math.Floor(sessionStartedAt.Value.ToUnixTimeMilliseconds() / 1000d))
                    {
                        historyReplayComplete = true;
                    }
                    break;

                case ParsedLineKind.Token:
                    var observation = parsed.Token!;
                    var isInheritedReplay = false;
                    if (inheritsHistory && !historyReplayComplete)
                    {
                        if (inheritedHistoryEndOrdinal is not null
                            && observation.Ordinal is not null
                            && observation.Ordinal.Value > inheritedHistoryEndOrdinal.Value)
                        {
                            historyReplayComplete = true;
                        }
                        else
                        {
                            isInheritedReplay = true;
                        }
                    }

                    var normalized = UsageNormalizer.Normalize(observation, state);
                    state = normalized.State;
                    partial |= state.Quality == DataQuality.Partial;
                    if (isInheritedReplay || normalized.Delta is not { } delta || delta == TokenUsage.Zero)
                    {
                        break;
                    }

                    if (events.Count >= MaximumEventsPerSource)
                    {
                        throw new InvalidOperationException(
                            $"More than {MaximumEventsPerSource:N0} token events were found in one session.");
                    }

                    events.Add(new UsageEvent(
                        EventKey(sessionId, observation),
                        observation.OccurredAt,
                        delta));
                    break;

                case ParsedLineKind.Malformed:
                    partial = true;
                    break;
            }
        }

        return new ParsedFile(events, partial);
    }

    private static UsageSnapshot Aggregate(
        IReadOnlyList<UsageEvent> events,
        DateTimeOffset now,
        WeekStart weekStart,
        bool partial)
    {
        var timeZone = TimeZoneInfo.Local;
        var localNow = TimeZoneInfo.ConvertTime(now, timeZone);
        var todayStart = LocalStartUtc(localNow.Date, timeZone);
        var dayOffset = weekStart == WeekStart.Monday
            ? ((int)localNow.DayOfWeek + 6) % 7
            : (int)localNow.DayOfWeek;
        var weekStartUtc = LocalStartUtc(localNow.Date.AddDays(-dayOffset), timeZone);
        var monthStartUtc = LocalStartUtc(
            new DateTime(localNow.Year, localNow.Month, 1),
            timeZone);

        var today = TokenUsage.Zero;
        var week = TokenUsage.Zero;
        var month = TokenUsage.Zero;
        var allTime = TokenUsage.Zero;
        DateTimeOffset? newest = null;

        foreach (var usageEvent in events)
        {
            if (usageEvent.OccurredAt > now)
            {
                continue;
            }

            allTime = allTime.Add(usageEvent.Usage);
            if (usageEvent.OccurredAt >= monthStartUtc)
            {
                month = month.Add(usageEvent.Usage);
            }

            if (usageEvent.OccurredAt >= weekStartUtc)
            {
                week = week.Add(usageEvent.Usage);
            }

            if (usageEvent.OccurredAt >= todayStart)
            {
                today = today.Add(usageEvent.Usage);
            }

            if (newest is null || usageEvent.OccurredAt > newest.Value)
            {
                newest = usageEvent.OccurredAt;
            }
        }

        var quality = newest is null
            ? partial ? DataQuality.Partial : DataQuality.Unavailable
            : partial ? DataQuality.Partial : DataQuality.Exact;
        return new UsageSnapshot(today, week, month, allTime, quality, newest);
    }

    private static DateTimeOffset LocalStartUtc(DateTime localDate, TimeZoneInfo timeZone)
    {
        var local = DateTime.SpecifyKind(localDate, DateTimeKind.Unspecified);
        while (timeZone.IsInvalidTime(local))
        {
            local = local.AddMinutes(1);
        }

        return TimeZoneInfo.ConvertTimeToUtc(local, timeZone);
    }

    private static bool ContainsRelevantMarker(byte[] line)
    {
        var bytes = line.AsSpan();
        return bytes.IndexOf("\"token_count\""u8) >= 0
            || bytes.IndexOf("\"session_meta\""u8) >= 0
            || bytes.IndexOf("\"task_started\""u8) >= 0;
    }

    private static string EventKey(string sessionId, TokenObservation observation)
    {
        var material = string.Join(
            '|',
            "event-v2",
            $"session:{sessionId}",
            $"time:{observation.OccurredAt.UtcDateTime.Ticks}",
            $"ordinal:{observation.Ordinal?.ToString(CultureInfo.InvariantCulture) ?? "none"}",
            $"last:{UsageIdentity(observation.LastUsage)}",
            $"cumulative:{UsageIdentity(observation.CumulativeUsage)}");
        return HashIdentifier(material);
    }

    private static string UsageIdentity(TokenUsage? usage) => usage is null
        ? "none"
        : $"{usage.Value.InputTokens},{usage.Value.CachedInputTokens},{usage.Value.OutputTokens}";

    private static string? SessionIdentifierFromFilename(string path)
    {
        var stem = Path.GetFileNameWithoutExtension(path);
        if (stem.Length < 36)
        {
            return null;
        }

        var suffix = stem[^36..];
        return Guid.TryParse(suffix, out var identifier)
            ? identifier.ToString("D")
            : null;
    }

    private static string HashIdentifier(string value) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));

    private sealed record ParsedFile(IReadOnlyList<UsageEvent> Events, bool Partial);
    private sealed record CachedFile(FileStamp Stamp, IReadOnlyList<UsageEvent> Events, bool Partial);
    private readonly record struct FileStamp(long Length, long LastWriteTicks, long CreationTimeTicks)
    {
        public static FileStamp Read(string path)
        {
            var info = new FileInfo(path);
            return new FileStamp(info.Length, info.LastWriteTimeUtc.Ticks, info.CreationTimeUtc.Ticks);
        }
    }
}

internal sealed record BoundedLine(byte[]? Bytes, bool Oversized);

internal static class BoundedLineReader
{
    public static IEnumerable<BoundedLine> Read(
        Stream stream,
        CancellationToken cancellationToken)
    {
        var readBuffer = ArrayPool<byte>.Shared.Rent(64 * 1024);
        var lineBuffer = new ArrayBufferWriter<byte>(64 * 1024);
        var oversized = false;
        try
        {
            while (true)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var read = stream.Read(readBuffer, 0, readBuffer.Length);
                if (read == 0)
                {
                    if (oversized || lineBuffer.WrittenCount > 0)
                    {
                        yield return new BoundedLine(null, true);
                    }
                    yield break;
                }

                for (var index = 0; index < read; index++)
                {
                    var value = readBuffer[index];
                    if (value == (byte)'\n')
                    {
                        yield return oversized
                            ? new BoundedLine(null, true)
                            : new BoundedLine(lineBuffer.WrittenMemory.ToArray(), false);
                        lineBuffer.Clear();
                        oversized = false;
                        continue;
                    }

                    if (oversized)
                    {
                        continue;
                    }

                    if (lineBuffer.WrittenCount >= CodexJsonlParser.MaximumLineBytes)
                    {
                        lineBuffer.Clear();
                        oversized = true;
                        continue;
                    }

                    lineBuffer.GetSpan(1)[0] = value;
                    lineBuffer.Advance(1);
                }
            }
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(readBuffer);
        }
    }
}
