using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows;
using CodexMeter.Core.Domain;
using CodexMeter.Core.Services;
using CodexMeter.Windows.Services;

namespace CodexMeter.Windows.ViewModels;

public sealed class UsageViewModel : INotifyPropertyChanged
{
    private readonly AppSettingsStore settingsStore;
    private readonly UsageScanner scanner = new();
    private readonly CoalescingRefreshRunner refreshRunner = new();
    private UsageSnapshot snapshot = UsageSnapshot.Empty;
    private string statusMessage = "Reading local Codex usage…";
    private bool isRefreshing;

    public UsageViewModel(AppSettingsStore settingsStore)
    {
        this.settingsStore = settingsStore;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public UsageSnapshot Snapshot => snapshot;
    public bool IsRefreshing => isRefreshing;
    public string StatusMessage => statusMessage;
    public string TodayTotal => Format(snapshot.Today.TotalTokens);
    public string TodayInput => Format(snapshot.Today.InputTokens);
    public string TodayCachedInput => Format(snapshot.Today.CachedInputTokens);
    public string TodayOutput => Format(snapshot.Today.OutputTokens);
    public string WeekTotal => Format(snapshot.Week.TotalTokens);
    public string MonthTotal => Format(snapshot.Month.TotalTokens);
    public string AllTimeTotal => Format(snapshot.AllTime.TotalTokens);
    public Visibility CachedVisibility => settingsStore.Current.ShowCachedInput
        ? Visibility.Visible
        : Visibility.Collapsed;
    public string LastUpdated => snapshot.UpdatedAt is null
        ? string.Empty
        : $"Latest local event {snapshot.UpdatedAt.Value.ToLocalTime():g}";
    public string TrayToolTip => snapshot.UpdatedAt is null
        ? "CodexMeter — no local usage"
        : $"CodexMeter — {TodayTotal} tokens today";

    public Task RefreshAsync() => refreshRunner.RunAsync(RefreshCoreAsync);

    public void InvalidateCachedSources() => scanner.InvalidateCachedSources();

    private async Task RefreshCoreAsync()
    {
        try
        {
            SetRefreshing(true);
            statusMessage = "Reading local Codex usage…";
            RaiseAll();
            var result = await scanner.ScanAsync(settingsStore.Current.WeekStart).ConfigureAwait(true);
            snapshot = result.Snapshot;
            statusMessage = result.StatusMessage;
            RaiseAll();
        }
        catch (OperationCanceledException)
        {
            statusMessage = snapshot.UpdatedAt is null
                ? "Refresh cancelled"
                : "Showing the last good update";
            RaiseAll();
        }
#pragma warning disable CA1031 // The tray must retain the last good snapshot for any non-fatal source failure.
        catch (Exception error) when (error is not OutOfMemoryException)
        {
            snapshot = snapshot with
            {
                Quality = snapshot.UpdatedAt is null ? DataQuality.Error : DataQuality.Stale
            };
            statusMessage = snapshot.UpdatedAt is null
                ? "Unable to read local usage"
                : "Showing the last good update";
            RaiseAll();
        }
#pragma warning restore CA1031
        finally
        {
            SetRefreshing(false);
        }
    }

    public void ApplySettings() => RaiseAll();

    private string Format(long value) =>
        TokenFormatter.Format(value, settingsStore.Current.NumberStyle);

    private void SetRefreshing(bool value)
    {
        if (isRefreshing == value)
        {
            return;
        }

        isRefreshing = value;
        OnPropertyChanged(nameof(IsRefreshing));
    }

    private void RaiseAll()
    {
        OnPropertyChanged(nameof(Snapshot));
        OnPropertyChanged(nameof(StatusMessage));
        OnPropertyChanged(nameof(TodayTotal));
        OnPropertyChanged(nameof(TodayInput));
        OnPropertyChanged(nameof(TodayCachedInput));
        OnPropertyChanged(nameof(TodayOutput));
        OnPropertyChanged(nameof(WeekTotal));
        OnPropertyChanged(nameof(MonthTotal));
        OnPropertyChanged(nameof(AllTimeTotal));
        OnPropertyChanged(nameof(CachedVisibility));
        OnPropertyChanged(nameof(LastUpdated));
        OnPropertyChanged(nameof(TrayToolTip));
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
