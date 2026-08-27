using System.IO;
using System.Text.Json;
using CodexMeter.Core.Domain;
using CodexMeter.Core.Services;

namespace CodexMeter.Windows.Services;

public sealed record AppSettings(
    TokenNumberStyle NumberStyle,
    WeekStart WeekStart,
    int RefreshIntervalSeconds,
    bool ShowCachedInput,
    bool LaunchAtLogin)
{
    public static AppSettings Default { get; } = new(
        TokenNumberStyle.Compact,
        WeekStart.Monday,
        60,
        true,
        false);
}

public sealed class AppSettingsStore
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        WriteIndented = true
    };

    private readonly string settingsPath;

    public AppSettingsStore()
    {
        var root = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "CodexMeter");
        Directory.CreateDirectory(root);
        settingsPath = Path.Combine(root, "settings.json");
        Current = Load();
    }

    public event Action? SettingsChanged;

    public AppSettings Current { get; private set; }

    public void Save(AppSettings settings)
    {
        settings = Normalize(settings);
        var temporaryPath = settingsPath + ".new";
        var json = JsonSerializer.Serialize(settings, SerializerOptions);
        File.WriteAllText(temporaryPath, json);
        File.Move(temporaryPath, settingsPath, true);
        Current = settings;
        StartupService.SetEnabled(settings.LaunchAtLogin);
        SettingsChanged?.Invoke();
    }

    private AppSettings Load()
    {
        try
        {
            if (!File.Exists(settingsPath))
            {
                return AppSettings.Default;
            }

            return Normalize(
                JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(settingsPath))
                    ?? AppSettings.Default);
        }
        catch (Exception error) when (error is IOException
                                      or UnauthorizedAccessException
                                      or JsonException)
        {
            return AppSettings.Default;
        }
    }

    private static AppSettings Normalize(AppSettings settings)
    {
        var numberStyle = Enum.IsDefined(settings.NumberStyle)
            ? settings.NumberStyle
            : AppSettings.Default.NumberStyle;
        var weekStart = Enum.IsDefined(settings.WeekStart)
            ? settings.WeekStart
            : AppSettings.Default.WeekStart;
        var refreshInterval = settings.RefreshIntervalSeconds is 0 or 30 or 60 or 300
            ? settings.RefreshIntervalSeconds
            : AppSettings.Default.RefreshIntervalSeconds;
        return settings with
        {
            NumberStyle = numberStyle,
            WeekStart = weekStart,
            RefreshIntervalSeconds = refreshInterval
        };
    }
}
