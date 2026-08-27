using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using CodexMeter.Core.Domain;
using CodexMeter.Core.Services;
using CodexMeter.Windows.Services;
using CodexMeter.Windows.ViewModels;

namespace CodexMeter.Windows.Views;

public partial class SettingsWindow : Window
{
    private const string ReleasesUrl = "https://github.com/HechoLP/CodexMeter/releases";
    private readonly AppSettingsStore settingsStore;
    private readonly UsageViewModel viewModel;

    public SettingsWindow(AppSettingsStore settingsStore, UsageViewModel viewModel)
    {
        InitializeComponent();
        this.settingsStore = settingsStore;
        this.viewModel = viewModel;
        LoadSettings();
    }

    private void LoadSettings()
    {
        var settings = settingsStore.Current;
        SelectByTag(NumberStyleBox, settings.NumberStyle.ToString());
        SelectByTag(WeekStartBox, settings.WeekStart.ToString());
        SelectByTag(RefreshBox, settings.RefreshIntervalSeconds.ToString());
        ShowCachedBox.IsChecked = settings.ShowCachedInput;
        LaunchAtLoginBox.IsChecked = settings.LaunchAtLogin;
    }

    private void SaveClicked(object sender, RoutedEventArgs e)
    {
        try
        {
            var numberStyle = Enum.Parse<TokenNumberStyle>(SelectedTag(NumberStyleBox));
            var weekStart = Enum.Parse<WeekStart>(SelectedTag(WeekStartBox));
            var refreshSeconds = int.Parse(SelectedTag(RefreshBox));
            settingsStore.Save(new AppSettings(
                numberStyle,
                weekStart,
                refreshSeconds,
                ShowCachedBox.IsChecked == true,
                LaunchAtLoginBox.IsChecked == true));
            viewModel.ApplySettings();
            Close();
        }
        catch (Exception error) when (error is IOException
                                      or UnauthorizedAccessException
                                      or System.Security.SecurityException)
        {
            ErrorText.Text = "Settings could not be saved.";
        }
    }

    private void OpenReleasesClicked(object sender, RoutedEventArgs e) =>
        Process.Start(new ProcessStartInfo(ReleasesUrl) { UseShellExecute = true });

    private static string SelectedTag(System.Windows.Controls.ComboBox box) =>
        ((ComboBoxItem)box.SelectedItem).Tag.ToString()!;

    private static void SelectByTag(System.Windows.Controls.ComboBox box, string tag)
    {
        foreach (var item in box.Items.OfType<ComboBoxItem>())
        {
            if (string.Equals(item.Tag?.ToString(), tag, StringComparison.Ordinal))
            {
                box.SelectedItem = item;
                return;
            }
        }

        box.SelectedIndex = 0;
    }
}
