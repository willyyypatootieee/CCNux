// Coordinates application launches that share a Wine prefix. Installation
// and repair remain exclusive elsewhere; this class tracks live Adobe
// applications so one app cannot be mistaken for another's launcher. Linux
// memory and swap policy decide the practical concurrency.
public class WineLaunchCoordinator : Object {
    private HashTable<string, bool> reservations = new HashTable<string, bool> (str_hash, str_equal);

    public uint active_count { get { return reservations.size (); } }

    public bool is_reserved (string product_id) { return reservations.contains (product_id); }

    public bool reserve (string product_id) {
        if (is_reserved (product_id)) return false;
        reservations.insert (product_id, true);
        return true;
    }

    public bool release (string product_id) { return reservations.remove (product_id); }
}
