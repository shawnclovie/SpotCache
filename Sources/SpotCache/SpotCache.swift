import Spot

extension Log.Level {
	public static var spotcache: Log.Level = .fatal
}

public enum CacheTarget {
	case memory, disk
}
