import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';
import 'package:preferences/preferences.dart';

Future<DiagnosticTorContext> loadTorDiagnosticContext(
  TorProxyPreferencesReader preferences,
  Tor client,
) async {
  final result = await preferences.readTorProxyPreferences();
  final saved = result.fold((value) => value, (_) => null);
  if (saved == null) {
    return const DiagnosticTorContext(state: 'uninitialized');
  }
  if (saved.useTorProxy) {
    final state = await client.external.verify(
      TorProxyEndpoint(
        host: InternetAddress.loopbackIPv4.address,
        port: saved.torProxyPort,
      ),
    );
    return _diagnosticTorState(state, socksProxyConfigured: true);
  }
  return _diagnosticTorState(
    client.embedded.current,
    socksProxyConfigured: false,
  );
}

DiagnosticTorContext _diagnosticTorState(
  TorConnectionState state, {
  required bool socksProxyConfigured,
}) {
  final source = state.source?.name;
  final transport = switch (state) {
    TorConnecting(:final transport) => transport?.name,
    TorReady(:final route) => route.transport?.name,
    _ => null,
  };
  final progress = switch (state) {
    TorConnecting(:final progress?) => (progress * 100).round().clamp(0, 100),
    _ => null,
  };
  final diagnostic = switch (state) {
    TorConnecting(:final diagnostic) => diagnostic?.name,
    _ => null,
  };
  return DiagnosticTorContext(
    source: source,
    state: switch (state) {
      TorUninitialized() => 'uninitialized',
      TorStopped() => 'stopped',
      TorConnecting() => 'connecting',
      TorReady() => 'ready',
      TorUnavailable() => 'unavailable',
    },
    transport: transport,
    progressPercent: progress,
    diagnostic: diagnostic,
    socksProxyConfigured: socksProxyConfigured,
  );
}
