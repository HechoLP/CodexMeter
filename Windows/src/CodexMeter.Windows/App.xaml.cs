using System.Threading;
using System.Windows;
using CodexMeter.Windows.Services;
using CodexMeter.Windows.Tray;
using CodexMeter.Windows.ViewModels;
using CodexMeter.Windows.Views;

namespace CodexMeter.Windows;

#pragma warning disable CA1001 // WPF owns the application lifetime; OnExit disposes every owned resource.
public partial class App : System.Windows.Application
{
    private Mutex? singleInstanceMutex;
    private TrayIconHost? trayIcon;
    private UsageWindow? usageWindow;
    private SettingsWindow? settingsWindow;
    private UsageViewModel? viewModel;
    private SessionWatcher? sessionWatcher;
    private System.Threading.Timer? refreshTimer;
    private AppSettingsStore? settingsStore;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        singleInstanceMutex = new Mutex(true, "Local\\CodexMeter.Windows", out var createdNew);
        if (!createdNew)
        {
            Shutdown();
            return;
        }

        settingsStore = new AppSettingsStore();
        viewModel = new UsageViewModel(settingsStore);
        usageWindow = new UsageWindow(viewModel);
        usageWindow.SettingsRequested += (_, _) => ShowSettings();
        usageWindow.QuitRequested += (_, _) => ShutdownApplication();

        trayIcon = new TrayIconHost(
            usageWindow.ToggleNearTray,
            () => _ = viewModel.RefreshAsync(),
            ShowSettings,
            ShutdownApplication);

        sessionWatcher = new SessionWatcher(
            changedPath => Dispatcher.BeginInvoke(() =>
            {
                if (changedPath is null)
                {
                    viewModel.InvalidateCachedSources();
                }
                else
                {
                    viewModel.InvalidateCachedSource(changedPath);
                }
                _ = viewModel.RefreshAsync();
            }));
        settingsStore.SettingsChanged += (_, _) => ApplySettings();
        ApplySettings();
        _ = viewModel.RefreshAsync();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        refreshTimer?.Dispose();
        sessionWatcher?.Dispose();
        trayIcon?.Dispose();
        singleInstanceMutex?.Dispose();
        base.OnExit(e);
    }

    private void ShowSettings()
    {
        if (settingsStore is null || viewModel is null)
        {
            return;
        }

        if (settingsWindow is null)
        {
            settingsWindow = new SettingsWindow(settingsStore);
            settingsWindow.Closed += (_, _) => settingsWindow = null;
        }
        settingsWindow.Show();
        settingsWindow.Activate();
    }

    private void ApplySettings()
    {
        if (settingsStore is null || viewModel is null)
        {
            return;
        }

        viewModel.ApplySettings();
        var seconds = settingsStore.Current.RefreshIntervalSeconds;
        refreshTimer?.Dispose();
        refreshTimer = seconds <= 0
            ? null
            : new System.Threading.Timer(
                _ => Dispatcher.BeginInvoke(() => _ = viewModel.RefreshAsync()),
                null,
                TimeSpan.FromSeconds(seconds),
                TimeSpan.FromSeconds(seconds));
        _ = viewModel.RefreshAsync();
    }

    private void ShutdownApplication()
    {
        usageWindow?.CloseForExit();
        settingsWindow?.Close();
        Shutdown();
    }
}
#pragma warning restore CA1001
