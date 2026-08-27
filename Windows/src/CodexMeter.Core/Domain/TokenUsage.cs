namespace CodexMeter.Core.Domain;

public readonly record struct TokenUsage(
    long InputTokens,
    long CachedInputTokens,
    long OutputTokens)
{
    public static TokenUsage Zero { get; } = new(0, 0, 0);

    public long TotalTokens => SaturatingAdd(
        SaturatingAdd(InputTokens, CachedInputTokens),
        OutputTokens);

    public bool IsValid => InputTokens >= 0
        && CachedInputTokens >= 0
        && OutputTokens >= 0
        && CachedInputTokens <= InputTokens;

    public TokenUsage Add(TokenUsage other) => new(
        SaturatingAdd(InputTokens, other.InputTokens),
        SaturatingAdd(CachedInputTokens, other.CachedInputTokens),
        SaturatingAdd(OutputTokens, other.OutputTokens));

    public TokenUsage SubtractFloorAtZero(TokenUsage previous) => new(
        Math.Max(0, InputTokens - previous.InputTokens),
        Math.Max(0, CachedInputTokens - previous.CachedInputTokens),
        Math.Max(0, OutputTokens - previous.OutputTokens));

    public TokenUsage ComponentWiseMaximum(TokenUsage other) => new(
        Math.Max(InputTokens, other.InputTokens),
        Math.Max(CachedInputTokens, other.CachedInputTokens),
        Math.Max(OutputTokens, other.OutputTokens));

    public bool IsComponentWiseAtLeast(TokenUsage other) =>
        InputTokens >= other.InputTokens
        && CachedInputTokens >= other.CachedInputTokens
        && OutputTokens >= other.OutputTokens;

    private static long SaturatingAdd(long left, long right)
    {
        try
        {
            return checked(left + right);
        }
        catch (OverflowException)
        {
            return long.MaxValue;
        }
    }
}
