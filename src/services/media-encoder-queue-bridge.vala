// Host-side bridge for applications that can hand a local render source to
// CCNux through a URI. It does not patch Premiere Pro or After Effects: the
// native Adobe Dynamic Link menu remains owned by Adobe.
public class MediaEncoderQueueBridge : Object {
    private const string SCHEME = "ccnux-media-encoder://";

    public static bool accepts (string uri) {
        return uri.has_prefix (SCHEME + "enqueue?");
    }

    public static bool is_dynamic_link_project (string path) {
        string lower = path.down ();
        return lower.has_suffix (".aep") || lower.has_suffix (".aet") || lower.has_suffix (".prproj");
    }

    public static string queue_description (string path) {
        if (is_dynamic_link_project (path))
            return "Dynamic Link project received. CCNux can start Media Encoder, but Adobe's native After Effects/Premiere queue is unavailable until Wine keeps Dynamic Link IPC alive.";
        return "Media source received for the Adobe Media Encoder queue.";
    }

    // Accepted form: ccnux-media-encoder://enqueue?file=file:///absolute/path
    // `path=/absolute/path` is also accepted for simple shell integrations.
    public string? source_from_uri (string uri) {
        if (!accepts (uri)) return null;
        int query_start = uri.index_of_char ('?');
        if (query_start < 0) return null;

        string[] pairs = uri.substring (query_start + 1).split ("&");
        foreach (string pair in pairs) {
            int separator = pair.index_of_char ('=');
            if (separator < 1) continue;
            string key = pair.substring (0, separator);
            if (key != "file" && key != "path") continue;

            string? decoded = Uri.unescape_string (pair.substring (separator + 1), null);
            if (decoded == null || decoded == "") return null;
            string? path = decoded.has_prefix ("file://") ? File.new_for_uri (decoded).get_path () : decoded;
            if (path == null || !Path.is_absolute (path)) return null;

            var source = File.new_for_path (path);
            if (!source.query_exists () || source.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY) return null;
            return path;
        }
        return null;
    }
}
