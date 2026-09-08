import 'dart:async';
import 'dart:io';

import 'onion_connection_failure.dart';

/// Keeps only the short, destination-free cause of the latest SOCKS failure.
///
/// The value is single-use: a caller must invalidate it before starting an
/// operation and consume it after the operation fails. This prevents a late
/// opaque SDK error from being attributed to an earlier connection attempt.
final class TorConnectionFailureRecorder {
  SocksConnectionFailureCause? _cause;

  void invalidate() => _cause = null;

  void record(Object error) {
    _cause = classifySocksConnectionFailure(error);
  }

  SocksConnectionFailureCause? take() {
    final cause = _cause;
    _cause = null;
    return cause;
  }

  Future<ConnectionTask<Socket>> Function(Uri, String?, int?) wrap(
    Future<ConnectionTask<Socket>> Function(Uri, String?, int?) delegate,
  ) => (uri, proxyHost, proxyPort) async {
    try {
      final task = await delegate(uri, proxyHost, proxyPort);
      final socket = task.socket.then(
        (value) => value,
        onError: (Object error, StackTrace trace) {
          record(error);
          Error.throwWithStackTrace(error, trace);
        },
      );
      return ConnectionTask.fromSocket(socket, task.cancel);
    } catch (error) {
      record(error);
      rethrow;
    }
  };
}
