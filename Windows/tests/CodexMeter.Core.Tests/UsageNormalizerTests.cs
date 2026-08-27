using CodexMeter.Core.Domain;
using CodexMeter.Core.Services;

namespace CodexMeter.Core.Tests;

public sealed class UsageNormalizerTests
{
    private readonly UsageNormalizer normalizer = new();
    private readonly DateTimeOffset timestamp = DateTimeOffset.Parse("2026-08-27T01:02:03Z");

    [Fact]
    public void UsesCumulativeIncreaseAndIgnoresRepeatedSnapshot()
    {
        var first = normalizer.Normalize(Observation(new TokenUsage(100, 60, 20)), UsageNormalizationState.Empty);
        var repeated = normalizer.Normalize(Observation(new TokenUsage(100, 60, 20)), first.State);
        var increased = normalizer.Normalize(Observation(new TokenUsage(130, 80, 25)), repeated.State);

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

        var result = normalizer.Normalize(observation, UsageNormalizationState.Empty);

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

        var result = normalizer.Normalize(
            new TokenObservation(timestamp, 2, fresh, fresh),
            previous);

        Assert.Equal(fresh, result.Delta);
        Assert.Equal(DataQuality.Partial, result.State.Quality);
    }

    private TokenObservation Observation(TokenUsage usage) =>
        new(timestamp, 1, usage, usage);
}
