public class DownloadService : Object {
    public Soup.Session session = new Soup.Session ();
    public async void download (string uri, File destination, Cancellable? cancellable = null) throws Error {
        var message = new Soup.Message ("GET", uri); var bytes = yield session.send_and_read_async (message, Priority.DEFAULT, cancellable);
        string etag; yield destination.replace_contents_async (bytes.get_data (), null, false, FileCreateFlags.REPLACE_DESTINATION, cancellable, out etag);
    }

    public async string get_latest_github_release_asset (string repo, string asset_pattern, Cancellable? cancellable = null) throws Error {
        string url = "https://api.github.com/repos/" + repo + "/releases/latest";
        var message = new Soup.Message ("GET", url);
        message.request_headers.append ("User-Agent", "CCNux-Downloader");
        var bytes = yield session.send_and_read_async (message, Priority.DEFAULT, cancellable);
        string json = (string) bytes.get_data ();
        try {
            var regex = new Regex ("\"browser_download_url\":\\s*\"([^\"]+" + asset_pattern + ")\"");
            MatchInfo match_info;
            if (regex.match (json, 0, out match_info)) return match_info.fetch (1);
        } catch (RegexError e) { throw new IOError.FAILED ("Regex error parsing GitHub release: " + e.message); }
        throw new IOError.NOT_FOUND ("Could not find asset matching " + asset_pattern + " in latest release for " + repo);
    }
}
