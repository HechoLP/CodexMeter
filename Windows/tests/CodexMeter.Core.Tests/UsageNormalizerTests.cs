using CodexMeter.Core.Domain;
using CodexMeter.Core.Services;
using System.Globalization;

namespace CodexMeter.Core.Tests;

public sealed class UsageNormalizerTests
{
    private readonly DateTimeOffset timestamp = DateTimeOffset.Parse(
        "2026-08-27T01:02:03Z",
        CultureInfo.InvariantCulture);

    [Fact]
    public void TotalCountsCachedInputOnlyAsPartOfInput()
    {
        var usage = new TokenUsage(1_200, 800, 300);

        Assert.Equal(1_500, usage.TotalTokens);
    }

    [Fact]
    public void UsesCumulativeIncreaseAndIgnoresRepeatedSnapshot()
    {
        var first = UsageNormalizer.Normalize(Observation(new TokenUsage(100, 60, 20)), UsageNormalizationState.Empty);
        var repeated = UsageNormalizer.Normalize(Observation(new TokenUsage(100, 60, 20)), first.State);
        var increased = UsageNormalizer.Normalize(Observation(new TokenUsage(130, 80, 25)), repeated.State);

        Assert.Equal(new TokenUsage(100, 60, 20), first.Delta);
        Assert.Null(repeated.Delta);
        Assert.Equal(new TokenUsage(30, 20, 5), increased.Delta);
    }

    [Fact]
    public void DoesNotGuessAnAmbiguousInitialBaseline()
    {
        var observation = new TokenObservation(
            timestamp,
            1,
            new TokenUsage(100, 80, 10),
            new TokenUsage(500, 300, 50));

        var result = UsageNormalizer.Normalize(observation, UsageNormalizationState.Empty);

        Assert.Null(result.Delta);
        Assert.Equal(DataQuality.Partial, result.State.Quality);
    }

    [Fact]
    public void CountsAValidatedCounterRestartAsPartial()
    {
        var previous = new UsageNormalizationState(
            new TokenUsage(1_000, 700, 100),
            timestamp.AddMinutes(-1),
            DataQuality.Exact);
        var fresh = new TokenUsage(50, 20, 10);

        var result = UsageNormalizer.Normalize(
            new TokenObservation(timestamp, 2, fresh, fresh),
            previous);

        Assert.Equal(fresh, result.Delta);
        Assert.Equal(DataQuality.Partial, result.State.Quality);
    }

    private TokenObservation Observation(TokenUsage usage) =>
        new(timestamp, 1, usage, usage);
}
