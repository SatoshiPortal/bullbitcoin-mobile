import 'dart:io';

import 'package:preferences/preferences.dart';
import 'package:bull_tor/tor.dart';
import 'package:primitives/primitives.dart';

enum ExternalTorProxyStatus { disabled, available, unavailable, unreadable }

extension ExternalTorProxyStatusAttention on ExternalTorProxyStatus {
  /// Whether the user has to act in the Tor settings: a proxy that is off or
  /// that answers is not what hides the network, so those keep the Electrum
  /// settings as the fix, while a proxy that should work and does not route
  /// the user to its own settings.
  bool get needsSettingsAttention => switch (this) {
    ExternalTorProxyStatus.unavailable ||
    ExternalTorProxyStatus.unreadable => true,
    ExternalTorProxyStatus.available ||
    ExternalTorProxyStatus.disabled => false,
  };
}

abstract interface class ExternalTorProxyDiagnostic {
  const factory ExternalTorProxyDiagnostic(
    TorProxyPreferencesReader preferences,
    Tor tor,
  ) = _ExternalTorProxyDiagnostic;

  Future<ExternalTorProxyStatus> check();
}

final class _ExternalTorProxyDiagnostic implements ExternalTorProxyDiagnostic {
  final TorProxyPreferencesReader _settingsRepository;
  final Tor _tor;

  const _ExternalTorProxyDiagnostic(this._settingsRepository, this._tor);

  @override
  Future<ExternalTorProxyStatus> check() async {
    final TorProxyPreferences settings;
    try {
      switch (await _settingsRepository.readTorProxyPreferences()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return ExternalTorProxyStatus.unreadable;
      }
    } on Exception {
      return ExternalTorProxyStatus.unreadable;
    }
    if (!settings.useTorProxy) return ExternalTorProxyStatus.disabled;
    try {
      final endpoint = TorProxyEndpoint(
        host: InternetAddress.loopbackIPv4.address,
        port: settings.torProxyPort,
      );
      return switch (await _tor.external.verify(endpoint)) {
        TorReady() => ExternalTorProxyStatus.available,
        _ => ExternalTorProxyStatus.unavailable,
      };
    } on ArgumentError {
      return ExternalTorProxyStatus.unavailable;
    } on Exception {
      return ExternalTorProxyStatus.unavailable;
    }
  }
}
