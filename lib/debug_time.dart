

class DebugTime {
  // 17280 = seconds in a day / 5  →  1 virtual day per 5 real seconds
  static const double _speedMultiplier = 17280.0;

  static bool _enabled = false;
  static DateTime? _wallClockStart;  // real time when fast-forward was enabled
  static DateTime? _virtualStart;    // virtual "now" at the moment of enabling
  // Tracks the last virtual time reached, so resuming picks up where we left off
  static DateTime? _lastVirtualTime;

  /// True when fast-forward mode is active.
  static bool get isEnabled => _enabled;

  /// Start fast-forward mode.
  /// If this is a resume after a previous session, virtual time continues
  /// from where it left off rather than resetting to real time.
  static void enable() {
    _enabled = true;
    _wallClockStart = DateTime.now();
    // Resume from the furthest virtual time reached, or real now if first run
    _virtualStart = _lastVirtualTime ?? DateTime.now();
  }

  /// Stop fast-forward mode. Saves the current virtual time so the next
  /// enable() can resume from here rather than jumping back to real time.
  static void disable() {
    // Capture where virtual time got to before stopping
    _lastVirtualTime = now();
    _enabled = false;
    _wallClockStart = null;
    _virtualStart = null;
  }

  /// Resets everything, including the saved virtual time.
  /// Call this when the user clears all data.
  static void reset() {
    _enabled = false;
    _wallClockStart = null;
    _virtualStart = null;
    _lastVirtualTime = null;
  }

  /// Returns the current (possibly accelerated) time.
  /// Synchronous — safe to call anywhere DateTime.now() was used.
  static DateTime now() {
    if (!_enabled || _wallClockStart == null || _virtualStart == null) {
      // When paused, return the last virtual time reached (if any) so that
      // date comparisons stay consistent with what competitors saw
      return _lastVirtualTime ?? DateTime.now();
    }

    final wallElapsed = DateTime.now().difference(_wallClockStart!);
    final virtualMicroseconds =
        (wallElapsed.inMicroseconds * _speedMultiplier).round();
    return _virtualStart!.add(Duration(microseconds: virtualMicroseconds));
  }
}