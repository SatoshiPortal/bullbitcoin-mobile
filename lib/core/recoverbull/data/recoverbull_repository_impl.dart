import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:convert/convert.dart' as convert;
import 'package:meta/meta.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;
import 'package:socks5_proxy/exceptions.dart';
import 'package:bull_tor/tor.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';

/// Data boundary for the RecoverBull key server. Catches the
/// foreign exceptions the datasources/SDK throw, logs the raw reason, and
/// returns a [RecoverBullCoreFailure] — no exception crosses this boundary.
class RecoverBullRepositoryImpl implements RecoverBullRepository {
  final RecoverBullRemoteDatasource _remoteDatasource;
  final RecoverbullSettingsDatasource _recoverbullSettingsDatasource;

  factory RecoverBullRepositoryImpl({
    required RecoverBullRemoteDatasource remoteDatasource,
    required RecoverbullSettingsDatasource recoverbullSettingsDatasource,
  }) => RecoverBullRepositoryImpl._(
    remoteDatasource,
    recoverbullSettingsDatasource,
  );

  RecoverBullRepositoryImpl._(
    this._remoteDatasource,
    this._recoverbullSettingsDatasource,
  );

  @override
  Future<Result<Null, RecoverBullCoreFailure>> storeVaultKey(
    String identifier,
    String password,
    String salt,
    String vaultKey,
    TorProxyEndpoint endpoint,
  ) async {
    try {
      await _remoteDatasource.store(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        convert.hex.decode(_normalizeHex(vaultKey)),
        endpoint: endpoint,
      );
      return const Ok(null);
    } on recoverbull.KeyServerException catch (e, st) {
      log.severe(
        message: 'storeVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.severe(
        message: 'storeVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedCoreFailure('Vault key processing failed'),
      );
    }
  }

  @override
  Future<Result<String, RecoverBullCoreFailure>> fetchVaultKey(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  ) async {
    try {
      final vaultKey = await _remoteDatasource.fetch(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        endpoint: endpoint,
      );
      return Ok(convert.hex.encode(vaultKey));
    } on recoverbull.KeyServerException catch (e, st) {
      log.severe(
        message: 'fetchVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.severe(
        message: 'fetchVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      // The SDK rethrows transport exceptions from fetchBackupKey unchanged.
      // A failed Tor connection is actionable, not an unexpected crypto error.
      if (e is SocksClientException ||
          e is SocketException ||
          e is TimeoutException ||
          e is HttpException) {
        return const Err(
          KeyServerUnavailableFailure('Key server connection failed'),
        );
      }
      return const Err(
        RecoverBullUnexpectedCoreFailure('Vault key processing failed'),
      );
    }
  }

  @override
  Future<void> trashVaultKey(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  ) async {
    await _remoteDatasource.trash(
      convert.hex.decode(_normalizeHex(identifier)),
      utf8.encode(password),
      convert.hex.decode(_normalizeHex(salt)),
      endpoint: endpoint,
    );
  }

  @override
  Future<Result<void, RecoverBullCoreFailure>> checkConnection(
    TorProxyEndpoint endpoint,
  ) async {
    try {
      await _remoteDatasource.checkConnection(endpoint);
      return const Ok(null);
    } on KeyServerProbeException catch (e) {
      return Err(probeFailure(e));
    } catch (e) {
      return Err(KeyServerUnavailableFailure(e.toString()));
    }
  }

  /// The Tor connect reason wins: when it exists, `KeyServer` only saw a message.
  @visibleForTesting
  static KeyServerUnavailableFailure probeFailure(KeyServerProbeException e) {
    final error = e.error;
    final status = error is recoverbull.KeyServerException ? error.code : null;
    final cause = switch (e.connectFailure) {
      TorConnectFailure.timeout => KeyServerUnreachableCause.circuitTimeout,
      TorConnectFailure.torNetworkUnreachable =>
        KeyServerUnreachableCause.torNetworkUnreachable,
      TorConnectFailure.hostUnreachable =>
        KeyServerUnreachableCause.onionUnreachable,
      TorConnectFailure.refused => KeyServerUnreachableCause.connectionRefused,
      TorConnectFailure.proxyUnreachable => KeyServerUnreachableCause.proxyGone,
      TorConnectFailure.other => KeyServerUnreachableCause.unknown,
      null when error is TimeoutException =>
        KeyServerUnreachableCause.circuitTimeout,
      null when status != null => KeyServerUnreachableCause.httpError,
      null => KeyServerUnreachableCause.badResponse,
    };
    return KeyServerUnavailableFailure.because(
      cause,
      httpStatus: cause == KeyServerUnreachableCause.httpError ? status : null,
      logMessage: e.toString(),
    );
  }

  @override
  Future<Uri> fetchUrl() async {
    return await _recoverbullSettingsDatasource.fetch();
  }

  @override
  Future<void> storeUrl(Uri url) async {
    await _recoverbullSettingsDatasource.store(url);
  }

  @override
  Future<void> allowPermission(bool isGranted) async {
    await _recoverbullSettingsDatasource.allowPermission(isGranted);
  }

  @override
  Future<bool> fetchPermission() async {
    return await _recoverbullSettingsDatasource.fetchPermission();
  }

  // Mirrors the legacy `ServerError.fromException`, null-safe on the 429 path.
  RecoverBullCoreFailure _mapKeyServer(recoverbull.KeyServerException e) {
    final code = e.code;
    if (code == 401) return KeyServerInvalidCredentialsFailure(e.toString());
    if (code == 429) {
      final requestedAt = e.requestedAt;
      final cooldown = e.cooldownInMinutes;
      final retryIn = (requestedAt != null && cooldown != null)
          ? requestedAt
                .add(Duration(minutes: cooldown))
                .difference(DateTime.now())
          : null;
      return KeyServerRateLimitedFailure(
        retryIn: retryIn,
        logMessage: e.toString(),
      );
    }
    if (code != null && code >= 400 && code < 500) {
      return KeyServerRejectedFailure(e.toString());
    }
    return KeyServerUnavailableFailure(e.toString());
  }

  /// Vault keys and server identifiers reach us as raw user input (typed or
  /// pasted — the recovery screen has no input formatter). Strip formatting
  /// whitespace before decoding so a spaced or newline-terminated key (the
  /// reveal screen shows the key in 4-char groups) still decodes.
  String _normalizeHex(String input) => input.replaceAll(RegExp(r'\s'), '');
}
