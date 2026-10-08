import 'dart:async';

import '../domain/onion_connection_failure.dart';
import 'tor_connection_failure_classifier.dart';

/// Correlates a connection attempt with a destination-free transport cause.
/// Transport types remain private to the data adapter; callers only see causes.
final class TorConnectionFailureRecorder {
  static final Object _attemptKey = Object();

  TorConnectionFailureAttempt begin() => TorConnectionFailureAttempt._();

  void record(Object error) {
    recordCause(classifySocksConnectionFailure(error));
  }

  void recordCause(SocksConnectionFailureCause cause) {
    (Zone.current[_attemptKey] as TorConnectionFailureAttempt?)?._record(cause);
  }
}

final class TorConnectionFailureAttempt {
  SocksConnectionFailureCause? _cause;

  TorConnectionFailureAttempt._();

  Future<T> run<T>(Future<T> Function() operation) => runZoned(
    operation,
    zoneValues: {TorConnectionFailureRecorder._attemptKey: this},
  );

  SocksConnectionFailureCause? take() {
    final cause = _cause;
    _cause = null;
    return cause;
  }

  void _record(SocksConnectionFailureCause cause) => _cause = cause;
}
