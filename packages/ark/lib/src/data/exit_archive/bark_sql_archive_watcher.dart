import 'dart:async';
import 'dart:io';

import 'package:primitives/primitives.dart';

import '../../../ark.dart';
import 'bark_sql_observation.dart';
import 'bark_sql_observer.dart';
import 'sqlite_exit_archive.dart';

enum BarkSqlWatchStage { source, archive, watch }

/// Owns one observer, one archive handle, one timer and one directory watch.
/// Captures observed states only; no native writer lease, copy or outbox promise.
final class BarkSqlArchiveWatcher {
  final BarkSqlObserverPort observer;
  final SqliteExitArchive archive;
  final Duration fallbackInterval;
  final Duration changeCoalesce;
  final void Function(BarkSqlWatchStage, ArkWalletFailure?)? onStatus;
  Timer? _timer;
  StreamSubscription<FileSystemEvent>? _events;
  final Stopwatch _clock = Stopwatch()..start();
  int? _due;
  Future<Result<bool, ArkWalletFailure>>? _flight;
  Future<void>? _closing;
  bool _started = false, _closed = false, _reopen = false;
  ArkWalletFailure? _sourceFailure, _archiveFailure, _watchFailure;
  BarkSqlSourceToken? _lastObservedToken;
  int _captures = 0;
  ArkWalletFailure? get sourceFailure => _sourceFailure;
  ArkWalletFailure? get archiveFailure => _archiveFailure;
  ArkWalletFailure? get watchFailure => _watchFailure;
  BarkSqlSourceToken? get lastObservedToken => _lastObservedToken;
  int get captures => _captures;
  BarkSqlArchiveWatcher({
    required this.observer,
    required this.archive,
    this.fallbackInterval = const Duration(seconds: 5),
    this.changeCoalesce = const Duration(milliseconds: 100),
    this.onStatus,
  }) {
    if (fallbackInterval <= Duration.zero || changeCoalesce < Duration.zero) {
      throw ArgumentError('Invalid watcher interval');
    }
  }

  void _status(BarkSqlWatchStage stage, ArkWalletFailure? next) {
    final previous = switch (stage) {
      BarkSqlWatchStage.source => _sourceFailure,
      BarkSqlWatchStage.archive => _archiveFailure,
      BarkSqlWatchStage.watch => _watchFailure,
    };
    switch (stage) {
      case BarkSqlWatchStage.source:
        _sourceFailure = next;
      case BarkSqlWatchStage.archive:
        _archiveFailure = next;
      case BarkSqlWatchStage.watch:
        _watchFailure = next;
    }
    if (previous?.runtimeType != next?.runtimeType ||
        previous?.reason != next?.reason) {
      onStatus?.call(stage, next);
    }
  }

  bool _samePath(String a, String b) =>
      File(a).absolute.uri.normalizePath() ==
      File(b).absolute.uri.normalizePath();
  bool _distinct() =>
      !_samePath(observer.sourcePath, archive.archivePath) &&
      !(File(observer.sourcePath).existsSync() &&
          File(archive.archivePath).existsSync() &&
          FileSystemEntity.identicalSync(
            File(observer.sourcePath).resolveSymbolicLinksSync(),
            File(archive.archivePath).resolveSymbolicLinksSync(),
          ));

  Result<void, ArkWalletFailure> start() {
    if (_closed) {
      return const Err(ArkUnavailableFailure(ArkFailureReason.closed));
    }
    try {
      if (!_distinct()) return const Err(ArkValidationFailure());
    } on FileSystemException {
      return const Err(ArkStorageFailure());
    }
    if (_started) return const Ok(null);
    _started = true;
    _listen();
    _request(_clock.elapsedMicroseconds);
    return const Ok(null);
  }

  void _listen() {
    try {
      _events = File(observer.sourcePath).parent.watch().listen(
        _event,
        onError: (Object _) {
          _watchLost();
        },
        onDone: _watchLost,
      );
    } on FileSystemException {
      _watchLost();
    }
  }

  void _watchLost() {
    if (_closed) return;
    _status(BarkSqlWatchStage.watch, const ArkStorageFailure());
    _reopen = true;
    _request(_clock.elapsedMicroseconds + fallbackInterval.inMicroseconds);
  }

  void _event(FileSystemEvent event) {
    if (_closed) return;
    final paths = [
      event.path,
      if (event is FileSystemMoveEvent && event.destination != null)
        event.destination,
    ];
    var interested = false;
    for (final path in paths) {
      if (path == null) continue;
      if (_samePath(path, observer.sourcePath)) {
        interested = true;
        if (event.type != FileSystemEvent.modify) _reopen = true;
      } else if (_samePath(path, '${observer.sourcePath}-wal') ||
          _samePath(path, '${observer.sourcePath}-journal')) {
        interested = true;
      } else if (_samePath(path, File(observer.sourcePath).parent.path)) {
        _watchLost();
      }
    }
    if (interested) {
      _request(_clock.elapsedMicroseconds + changeCoalesce.inMicroseconds);
    }
  }

  void _request(int at) {
    if (_closed || !_started) return;
    final previous = _due;
    if (previous == null || at < previous) _due = at;
    if (_flight != null) return;
    _timer?.cancel();
    final due = _due;
    if (due == null) return;
    final delay = Duration(microseconds: due - _clock.elapsedMicroseconds);
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () {
      _timer = null;
      _due = null;
      unawaited(capture());
    });
  }

  /// Known external source replacement uses the same deferred reader reset.
  void sourceReplaced() {
    if (_closed) return;
    _reopen = true;
    _request(_clock.elapsedMicroseconds + changeCoalesce.inMicroseconds);
  }

  Future<Result<bool, ArkWalletFailure>> capture() {
    if (_closed) {
      return Future.value(
        const Err(ArkUnavailableFailure(ArkFailureReason.closed)),
      );
    }
    final admitted = _flight;
    if (admitted != null) return admitted;
    _timer?.cancel();
    _timer = null;
    _due = null;
    late Future<Result<bool, ArkWalletFailure>> task;
    task =
        Future.sync(() async {
          try {
            if (!_distinct()) {
              _status(BarkSqlWatchStage.source, const ArkValidationFailure());
              return const Err<bool, ArkWalletFailure>(ArkValidationFailure());
            }
          } on FileSystemException {
            _status(BarkSqlWatchStage.source, const ArkStorageFailure());
            return const Err<bool, ArkWalletFailure>(ArkStorageFailure());
          }
          if (_reopen || _watchFailure != null) {
            observer.reopen();
            _reopen = false;
          }
          _captures++;
          final read = await observer.read();
          if (read case Err(:final failure)) {
            _status(BarkSqlWatchStage.source, failure);
            return Err<bool, ArkWalletFailure>(failure);
          }
          _status(BarkSqlWatchStage.source, null);
          final observation =
              (read as Ok<BarkSqlObservation, ArkWalletFailure>).value;
          _lastObservedToken = observation.sourceToken;
          final appended = await archive.appendSqlObservation(observation);
          _status(BarkSqlWatchStage.archive, switch (appended) {
            Err(:final failure) => failure,
            _ => null,
          });
          return appended;
        }).whenComplete(() {
          _flight = null;
          if (!_closed && _started) {
            _request(
              _due ??
                  _clock.elapsedMicroseconds + fallbackInterval.inMicroseconds,
            );
          }
        });
    _flight = task;
    return task;
  }

  Future<void> close() {
    final closing = _closing;
    if (closing != null) return closing;
    _closed = true;
    _started = false;
    _timer?.cancel();
    _timer = null;
    _due = null;
    final events = _events;
    _events = null;
    final admitted = _flight;
    return _closing = (() async {
      await events?.cancel();
      try {
        await admitted;
      } finally {
        await observer.close();
        await archive.close();
      }
    })();
  }
}
