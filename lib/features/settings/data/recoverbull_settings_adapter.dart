import 'dart:io';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';

/// Settings owns environment selection, proxy preference and the legacy row.
final class RecoverBullSettingsAdapter
    implements
        RecoverBullRoutePort,
        RecoverBullEnvironmentPort,
        RecoverBullLegacySettingsPort {
  final SettingsRepository _settings;
  final SqliteDatabase _database;
  final EmbeddedTor _embedded;
  final Tor _tor;

  const RecoverBullSettingsAdapter(
    this._settings,
    this._database,
    this._embedded,
    this._tor,
  );

  @override
  Future<Result<BitcoinNetwork, RecoverBullFailure>> currentNetwork() async {
    try {
      final settings = await _settings.fetch();
      return Ok(
        settings.environment.requireHistoricalTestnet()
            ? BitcoinNetwork.testnet
            : BitcoinNetwork.mainnet,
      );
    } on Exception {
      log.warning('recoverbull.environment.read.failed');
      return const Err(VaultStorageFailure());
    }
  }

  @override
  Future<Result<LegacyBackupSettings, RecoverBullFailure>> read() async {
    try {
      final row = await _database.managers.recoverbull
          .filter((f) => f.id(1))
          .getSingleOrNull();
      if (row == null) return const Err(VaultStorageFailure());
      return Ok(
        LegacyBackupSettings(
          server: Uri.parse(row.url),
          permissionGranted: row.isPermissionGranted,
        ),
      );
    } on FormatException {
      return const Err(VaultInvalidFailure());
    } on ArgumentError {
      return const Err(VaultInvalidFailure());
    } on Exception {
      log.warning('recoverbull.legacy.read.failed');
      return const Err(VaultStorageFailure());
    }
  }

  @override
  Stream<TorConnectionState> watch() => _embedded.states;

  @override
  bool get snowflakeAvailable => _embedded.mode == TorTransportMode.automatic;

  @override
  Future<Result<RecoverBullRoute, RecoverBullFailure>> open({
    bool restartEmbedded = false,
    bool viaSnowflake = false,
  }) async {
    try {
      final settings = await _settings.fetch();
      if (settings.useTorProxy) {
        final TorProxyEndpoint endpoint;
        try {
          endpoint = TorProxyEndpoint(
            host: InternetAddress.loopbackIPv4.address,
            port: settings.torProxyPort,
          );
        } on ArgumentError {
          return const Err(ExternalTorProxyUnavailableFailure());
        }
        return switch (await _tor.external.verify(endpoint)) {
          TorReady(:final route) => Ok(RecoverBullRoute(route, () async {})),
          _ => const Err(ExternalTorProxyUnavailableFailure()),
        };
      }
      // New route never restarts the shared engine or another flow's circuit;
      // only Retry after a failed or stalled bootstrap asks for a restart.
      final ready = restartEmbedded || viaSnowflake
          ? await _embedded.retry(snowflake: viaSnowflake)
          : await _embedded.ensureReady();
      if (ready is! TorReady || ready.route.source != TorSource.embedded) {
        return const Err(KeyServerFailure(KeyServerFailureKind.unavailable));
      }
      final session = await _embedded.sessions.open();
      return Ok(
        RecoverBullRoute(
          TorRoute(
            source: TorSource.embedded,
            endpoint: session.endpoint,
            evidence: TorReadinessEvidence.embeddedBootstrap,
            transport: session.transport,
          ),
          session.close,
        ),
      );
    } on Exception {
      log.warning('recoverbull.route.open.failed');
      return const Err(KeyServerFailure(KeyServerFailureKind.unavailable));
    }
  }
}
