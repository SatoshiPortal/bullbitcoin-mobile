import 'dart:io';

/// A local, non-identifying UTC-day marker. A failed read or write must not
/// result in an observation, since that could count an installation twice.
abstract interface class ActiveDayStore {
  Future<String?> read();
  Future<void> write(String day);
}

final class FileActiveDayStore implements ActiveDayStore {
  final File file;

  FileActiveDayStore(this.file);

  @override
  Future<String?> read() async {
    final String day;
    try {
      day = await file.readAsString();
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode == 2) return null;
      rethrow;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      throw const FormatException('Invalid active day marker');
    }
    return day;
  }

  @override
  Future<void> write(String day) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(day, flush: true);
    await temporary.rename(file.path);
  }
}

/// Serializes foreground and consent transitions within the foreground process.
/// Continuous foreground across midnight does not trigger another observation.
final class DailyActiveInstallations {
  final ActiveDayStore _store;
  final void Function(DateTime instant) _emit;
  final DateTime Function() _clock;
  Future<void> _pending = Future.value();
  bool _foreground = false;
  bool _consented = false;
  int _revision = 0;

  DailyActiveInstallations(
    this._store,
    this._emit, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    _revision++;
    if (foreground && _consented) _schedule();
  }

  void setConsent(bool consented) {
    if (_consented == consented) return;
    _consented = consented;
    _revision++;
    if (consented && _foreground) _schedule();
  }

  void _schedule() {
    _pending = _pending.then((_) => _observe());
  }

  Future<void> _observe() async {
    if (!_foreground || !_consented) return;
    final revision = _revision;
    final instant = _clock().toUtc();
    final day = instant.toIso8601String().substring(0, 10);
    try {
      final previous = await _store.read();
      if (previous != null && previous.compareTo(day) >= 0) return;
      if (revision != _revision || !_foreground || !_consented) return;
      await _store.write(day);
      if (revision == _revision && _foreground && _consented) {
        _emit(instant);
      }
    } on Exception {
      // Statistics must not interfere with the wallet.
    }
  }

  /// Wait for transitions already queued, primarily for deterministic tests.
  Future<void> get idle => _pending;
}
