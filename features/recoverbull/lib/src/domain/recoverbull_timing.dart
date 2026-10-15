/// Receives one timed phase of a key-server operation: its name, duration and
/// a non-secret outcome label.
typedef RecoverBullTiming =
    void Function(String phase, int durationMilliseconds, String outcome);
