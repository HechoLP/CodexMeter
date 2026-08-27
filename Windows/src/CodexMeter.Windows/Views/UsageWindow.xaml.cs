using System.ComponentModel;
using System.Windows;
using CodexMeter.Windows.ViewModels;

namespace CodexMeter.Windows.Views;

public partial class UsageWindow : Window
{
    private readonly UsageViewModel viewModel;
    private bool closingForExit;

    public UsageWindow(UsageViewModel viewModel)
    {
        InitializeComponent();
        this.viewModel = viewModel;
        DataContext = viewModel;
        Deactivated += (_, _) => Hide();
    }

    public event Action? SettingsRequested;
    public event Action? QuitRequested;

    public void ToggleNearTray()
    {
        if (IsVisible)
        {
            Hide();
            return;
        }

        var workArea = SystemParameters.WorkArea;
        Left = workArea.Right - Width - 14;
        Top = workArea.Bottom - Height - 14;
        Show();
        Activate();
        _ = viewModel.RefreshAsync();
    }

    public void CloseForExit()
    {
        closingForExit = true;
        Close();
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        if (!closingForExit)
        {
            e.Cancel = true;
            Hide();
        }
        base.OnClosing(e);
    }

    private void RefreshClicked(object sender, RoutedEventArgs e) =>
        _ = viewModel.RefreshAsync();

    private void SettingsClicked(object sender, RoutedEventArgs e)
    {
        Hide();
        SettingsRequested?.Invoke();
    }

    private void QuitClicked(object sender, RoutedEventArgs e) => QuitRequested?.Invoke();
}
