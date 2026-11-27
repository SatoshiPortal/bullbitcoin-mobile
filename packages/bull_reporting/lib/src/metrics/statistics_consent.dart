import 'dart:async';
import 'dart:io';

abstract interface class StatisticsConsentStore {
  Future<bool> read();
  Future<void> activate();
  Future<void> revoke();
}

/// The marker itself is the only durable source of statistics consent.
final class FileStatisticsConsentStore implements StatisticsConsentStore {
  final Future<File> Function() _file;
  static const _marker = 'statistics-consent-v1\n';

  FileStatisticsConsentStore(this._file);

  @override
  Future<bool> read() async {
    final file = await _file();
    if (!await file.exists()) return false;
    return await file.readAsString() == _marker;
  }

  @override
  Future<void> activate() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(_marker, flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> revoke() async {
    final file = await _file();
    try {
      await file.delete();
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode != 2) rethrow;
    }
  }
}

/// Serializes persistent changes and immediately closes the live gate on
/// withdrawal, including when the subsequent delete fails.
final class StatisticsConsent {
  final StatisticsConsentStore _store;
  final _changes = StreamController<bool>.broadcast(sync: true);
  Future<void> _pending = Future<void>.value();
  Future<void>? _initialization;
  bool _enabled = false;
  int _revision = 0;

  StatisticsConsent(this._store);

  bool get enabled => _enabled;
  Stream<bool> get changes => _changes.stream;

  void _publish(bool enabled) {
    _enabled = enabled;
    _changes.add(enabled);
  }

  Future<bool> initialize() async {
    await (_initialization ??= _initialize());
    return _enabled;
  }

  Future<void> _initialize() {
    final revision = _revision;
    final completion = Completer<void>();
    _pending = _pending.then((_) async {
      var enabled = false;
      try {
        enabled = await _store.read();
      } on Exception {
        // An absent, malformed or unreadable marker is not consent.
      }
      if (revision == _revision) _publish(enabled);
      completion.complete();
    });
    return completion.future;
  }

  /// Returns false when persistence failed. A failed withdrawal remains off
  /// in this process but may be read as on after restart if deletion failed.
  Future<bool> setEnabled(bool enabled) {
    final revision = ++_revision;
    if (!enabled) _publish(false);
    final completion = Completer<bool>();
    _pending = _pending.then((_) async {
      try {
        if (enabled) {
          await _store.activate();
          if (revision == _revision) _publish(true);
        } else {
          await _store.revoke();
        }
        completion.complete(true);
      } on Exception {
        completion.complete(false);
      }
    });
    return completion.future;
  }
}
