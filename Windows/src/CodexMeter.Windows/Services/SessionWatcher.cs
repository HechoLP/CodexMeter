using CodexMeter.Core.Services;
using System.IO;

namespace CodexMeter.Windows.Services;

internal sealed class SessionWatcher : IDisposable
{
    private readonly Action onChange;
    private readonly List<FileSystemWatcher> watchers = [];
    private readonly object timerLock = new();
    private System.Threading.Timer? debounceTimer;

    public SessionWatcher(Action onChange)
    {
        this.onChange = onChange;
        Rebuild();
    }

    public void Rebuild()
    {
        foreach (var watcher in watchers)
        {
            watcher.Dispose();
        }
        watchers.Clear();

        foreach (var root in UsageScanner.DefaultRoots().Where(Directory.Exists))
        {
            var watcher = new FileSystemWatcher(root, "*.jsonl")
            {
                IncludeSubdirectories = true,
                NotifyFilter = NotifyFilters.FileName
                    | NotifyFilters.LastWrite
                    | NotifyFilters.Size,
                InternalBufferSize = 16 * 1024,
                EnableRaisingEvents = true
            };
            watcher.Changed += HandleChange;
            watcher.Created += HandleChange;
            watcher.Deleted += HandleChange;
            watcher.Renamed += HandleChange;
            watcher.Error += HandleError;
            watchers.Add(watcher);
        }
    }

    public void Dispose()
    {
        foreach (var watcher in watchers)
        {
            watcher.Dispose();
        }
        watchers.Clear();
        lock (timerLock)
        {
            debounceTimer?.Dispose();
            debounceTimer = null;
        }
    }

    private void HandleChange(object sender, FileSystemEventArgs e) => ScheduleRefresh();

    private void HandleError(object sender, ErrorEventArgs e)
    {
        Rebuild();
        ScheduleRefresh();
    }

    private void ScheduleRefresh()
    {
        lock (timerLock)
        {
            debounceTimer?.Dispose();
            debounceTimer = new System.Threading.Timer(
                _ => onChange(),
                null,
                TimeSpan.FromSeconds(2),
                Timeout.InfiniteTimeSpan);
        }
    }
}
