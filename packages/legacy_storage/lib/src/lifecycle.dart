import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';

import 'package:ffi/ffi.dart';

/// A bounded infrastructure failure: never contains paths or native messages.
final class LifecycleException implements Exception {
  final String reason;
  const LifecycleException(this.reason);
}

final class NativeFileGate {
  static final Set<RuntimeAdmission> _runtimes = {};
  final File file;

  const NativeFileGate(this.file);

  Future<LifecycleAdmission> acquire({
    required bool exclusive,
    required Duration timeout,
  }) async {
    if (!(Platform.isLinux ||
        Platform.isAndroid ||
        Platform.isMacOS ||
        Platform.isIOS)) {
      throw const LifecycleException('unsupported');
    }
    if (exclusive &&
        _runtimes.any(
          (lease) => lease._path == file.absolute.path && lease.isOpen,
        )) {
      throw const LifecycleException('runtime_still_open');
    }
    file.parent.createSync(recursive: true);
    final native = _Posix();
    final stream = using(
      (arena) => native.fopen(
        file.path.toNativeUtf8(allocator: arena),
        'a+'.toNativeUtf8(allocator: arena),
      ),
    );
    if (stream == nullptr) throw const LifecycleException('open');
    final fd = native.fileno(stream);
    final clock = Stopwatch()..start();
    var transferred = false;
    try {
      do {
        if (native.flock(fd, (exclusive ? 2 : 1) | 4) == 0) {
          transferred = true;
          if (exclusive) {
            return ExclusiveAdmission._(native, stream, file.absolute.path);
          }
          final runtime = RuntimeAdmission._(
            native,
            stream,
            file.absolute.path,
          );
          _runtimes.add(runtime);
          return runtime;
        }
        final error = native.errno.value;
        // EAGAIN/EWOULDBLOCK differs between Linux and Darwin.
        if (error != (Platform.isMacOS || Platform.isIOS ? 35 : 11) &&
            error != 4) {
          throw const LifecycleException('lock');
        }
        if (clock.elapsed >= timeout) break;
        final remaining = timeout - clock.elapsed;
        await Future<void>.delayed(
          remaining < const Duration(milliseconds: 20)
              ? remaining
              : const Duration(milliseconds: 20),
        );
      } while (clock.elapsed < timeout);
      throw const LifecycleException('busy');
    } finally {
      if (!transferred) native.fclose(stream);
    }
  }
}

/// Owns the OS lock until every registered native resource confirms closure.
sealed class LifecycleAdmission {
  static final Set<LifecycleAdmission> _quarantine = {};
  final _Posix _native;
  final Pointer<Void> _stream;
  final String _path;
  final Set<LifecycleHandle> _handles = {};
  bool _closed = false;
  Future<void>? _closing;

  LifecycleAdmission._(this._native, this._stream, this._path);

  bool get isOpen => !_closed;

  LifecycleHandle track(Future<void> Function() close) {
    if (_closed || _closing != null) throw const LifecycleException('closed');
    final handle = LifecycleHandle._(this, close);
    _handles.add(handle);
    return handle;
  }

  Future<void> close() {
    if (_closed) return Future.value();
    return _closing ??= _close();
  }

  Future<void> _close() async {
    _quarantine.add(this);
    try {
      for (final handle in _handles.toList().reversed) {
        try {
          await handle.close();
        } on Exception {
          // The handle remains registered; continue closing independent resources.
        }
      }
      if (_handles.isNotEmpty) {
        _quarantine.add(this);
        throw const LifecycleException('resources_still_open');
      }
      // fclose closes this independently opened descriptor and releases its lock.
      // No explicit unlock may precede confirmed resource closure.
      if (_native.fclose(_stream) != 0) {
        _closed = true; // fclose consumes the stream even when flushing fails.
        _quarantine.remove(this);
        NativeFileGate._runtimes.remove(this);
        throw const LifecycleException('close');
      }
      _closed = true;
      _quarantine.remove(this);
      NativeFileGate._runtimes.remove(this);
    } finally {
      _closing = null;
    }
  }

  static Future<void> retryQuarantined() async {
    for (final admission in _quarantine.toList()) {
      await admission.close();
    }
  }
}

final class ExclusiveAdmission extends LifecycleAdmission {
  ExclusiveAdmission._(super.native, super.stream, super.path) : super._();
}

final class RuntimeAdmission extends LifecycleAdmission {
  RuntimeAdmission._(super.native, super.stream, super.path) : super._();
}

final class LifecycleHandle {
  final LifecycleAdmission _admission;
  final Future<void> Function() _dispose;
  Future<void>? _closing;
  bool _closed = false;

  LifecycleHandle._(this._admission, this._dispose);

  Future<void> close() {
    if (_closed) return Future.value();
    return _closing ??= _close();
  }

  Future<void> _close() async {
    try {
      await _dispose();
      _closed = true;
      _admission._handles.remove(this);
    } finally {
      _closing = null;
    }
  }
}

/// Persists the directory entry after publishing a marker in that directory.
void syncLifecycleDirectory(Directory directory) {
  final native = _Posix();
  final stream = using(
    (arena) => native.opendir(directory.path.toNativeUtf8(allocator: arena)),
  );
  if (stream == nullptr) throw const LifecycleException('directory_open');
  try {
    if (native.fsync(native.dirfd(stream)) != 0) {
      throw const LifecycleException('directory_sync');
    }
  } finally {
    native.closedir(stream);
  }
}

final class _Posix {
  final DynamicLibrary _lib = DynamicLibrary.process();
  late final fopen = _lib
      .lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>)
      >('fopen');
  late final fileno = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('fileno');
  late final fclose = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('fclose');
  late final flock = _lib
      .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
        'flock',
      );
  late final opendir = _lib
      .lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)
      >('opendir');
  late final dirfd = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('dirfd');
  late final closedir = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('closedir');
  late final fsync = _lib
      .lookupFunction<Int32 Function(Int32), int Function(int)>('fsync');
  late final _errno = _lib
      .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
        Platform.isAndroid
            ? '__errno'
            : Platform.isMacOS || Platform.isIOS
            ? '__error'
            : '__errno_location',
      );
  Pointer<Int32> get errno => _errno();
}

/// Internal worker protocol. A transport shutdown acknowledgement is not proof
/// that the native executor finished closing.
final class NativeCloseAcknowledgement extends QueryInterceptor {
  final SendPort _closed;
  bool _noHandle = false;
  NativeCloseAcknowledgement(this._closed);

  void openFailedWithoutHandle() {
    _noHandle = true;
  }

  @override
  Future<void> close(QueryExecutor inner) async {
    if (!_noHandle) await inner.close();
    _closed.send(true);
  }
}
