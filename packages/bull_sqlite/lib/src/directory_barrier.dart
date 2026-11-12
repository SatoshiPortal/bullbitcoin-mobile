import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _OpenNative = Int32 Function(Pointer<Utf8> path, Int32 flags);
typedef _Open = int Function(Pointer<Utf8> path, int flags);
typedef _FdNative = Int32 Function(Int32 fd);
typedef _Fd = int Function(int fd);

/// Makes the entries of one directory durable: a rename, a creation or an unlink in it survives a power loss once [sync] returns.
///
/// `dart:io` can flush a file's contents but not a directory, and a rename is a change to the directory. So this calls the C library directly: `open(dir, O_RDONLY)`, `fsync`, `close` — what SQLite itself does for its journals. On Darwin `fsync` leaves the drive's cache alone (`F_FULLFSYNC` would not); that is SQLite's default guarantee too.
abstract final class DirectoryBarrier {
  /// `O_RDONLY` is 0 on every platform this app ships on; opening a directory read-only needs no other flag.
  static const _readOnly = 0;

  static final _libc = DynamicLibrary.process();
  static final _open = _libc.lookupFunction<_OpenNative, _Open>('open');
  static final _fsync = _libc.lookupFunction<_FdNative, _Fd>('fsync');
  static final _close = _libc.lookupFunction<_FdNative, _Fd>('close');

  /// Throws [FileSystemException] if the directory cannot be opened or synced.
  static void sync(String directoryPath) {
    if (Platform.isWindows) {
      // Not a target of this app; NTFS has no directory fsync.
      return;
    }
    final path = directoryPath.toNativeUtf8();
    try {
      final fd = _open(path, _readOnly);
      if (fd < 0) {
        throw FileSystemException(
          'cannot open directory to sync it',
          directoryPath,
        );
      }
      final synced = _fsync(fd) == 0;
      // Closed whatever the sync said, and checked: a close that fails can be where a deferred write error surfaces. The sync failure, if any, is the one reported.
      final closed = _close(fd) == 0;
      if (!synced) {
        throw FileSystemException('cannot sync directory', directoryPath);
      }
      if (!closed) {
        throw FileSystemException(
          'cannot close synced directory',
          directoryPath,
        );
      }
    } finally {
      malloc.free(path);
    }
  }
}
