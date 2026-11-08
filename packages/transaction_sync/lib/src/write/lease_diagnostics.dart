import 'dart:async';

import 'writer_diagnostics.dart';

enum LeaseRole { reader, writer }

enum LeaseIntent {
  snapshot,
  sync,
  create,
  receive,
  delete,
  repair,
  reconcile,
  prepareReimport,
}

enum LeaseScope { foreground, compute, headless }

enum LeaseSource {
  syncStarted,
  syncStartedReload,
  walletList,
  balance,
  transactions,
  utxos,
  addressList,
  sendBuild,
  other,
}

enum LeaseRead { cache, hydrate, stale }

enum LeaseBusySource {
  leaseBegin,
  leaseOpen,
  revisionRead,
  lifecycleGate,
  schemaGate,
}

final _uppercase = RegExp('[A-Z]');

String _field(Enum value) => value.name.replaceAllMapped(
  _uppercase,
  (match) => '_${match[0]?.toLowerCase()}',
);

/// Diagnostic context only: never used for admission, retry or locking policy.
final class LeaseDiagnostics {
  static final _zoneKey = Object();
  static final _sourceKey = Object();
  final LeaseRole role;
  final LeaseIntent intent;
  final LeaseScope scope;
  final LeaseSource source;
  final WriterDiagnosticSink sink;
  LeaseRead read = LeaseRead.hydrate;

  LeaseDiagnostics({
    required this.role,
    required this.intent,
    this.scope = LeaseScope.foreground,
    LeaseSource? source,
    this.sink = persistWriterDiagnostic,
  }) : source = source ?? currentSource;

  static LeaseDiagnostics? get current =>
      Zone.current[_zoneKey] as LeaseDiagnostics?;
  static LeaseSource get currentSource =>
      Zone.current[_sourceKey] as LeaseSource? ?? LeaseSource.other;

  T run<T>(T Function() action) =>
      runZoned(action, zoneValues: {_zoneKey: this});

  /// Keep the initiating caller (for example sync_started) over a nested balance read.
  static T from<T>(LeaseSource source, T Function() action) => runZoned(
    action,
    zoneValues: {
      _sourceKey: currentSource == LeaseSource.other ? source : currentSource,
    },
  );

  void acquire({int waitedMs = 0}) {
    _emit('lease_acquire', 0);
    if (waitedMs >= 100) {
      _emit('lease_wait', 0, waitedMs: waitedMs, level: WriterLogLevel.fine);
    }
  }

  void release(int heldMs) {
    _emit('lease_release', heldMs);
    if (heldMs >= 1000) {
      _emit('lease_long_hold', heldMs, level: WriterLogLevel.fine);
    }
  }

  void busy(LeaseBusySource source, {int waitedMs = 0}) => _emit(
    'lease_busy',
    0,
    busySource: source,
    waitedMs: waitedMs,
    level: role == LeaseRole.writer ? WriterLogLevel.fine : WriterLogLevel.info,
  );

  void _emit(
    String event,
    int heldMs, {
    LeaseBusySource? busySource,
    int? waitedMs,
    WriterLogLevel level = WriterLogLevel.info,
  }) {
    // Capture inside the owner isolate, before forwarding to its logging owner.
    final timestamp = DateTime.now().toUtc().toIso8601String();
    try {
      sink(
        level,
        'event=$event role=${_field(role)} intent=${_field(intent)} '
        'scope=${_field(scope)} source=${_field(source)} read=${_field(read)} '
        'held_ms=$heldMs${busySource == null ? '' : ' busy_source=${_field(busySource)}'}${waitedMs == null ? '' : ' waited_ms=$waitedMs'} owner_at=$timestamp',
      );
    } on Object {
      // Best effort diagnostics must never leak a lease or change an outcome.
    }
  }
}
