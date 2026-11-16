import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart' show TorConnectFailure;
import 'package:convert/convert.dart' show hex;
import 'package:primitives/primitives.dart';
import 'package:recoverbull/recoverbull.dart' as client;
import 'package:secrets/secrets.dart' show VaultKey;

import '../domain/entities/attempt_observation.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/entities/vault_key_fetch.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/repositories/key_server_repository.dart';

/// The client owns protocol encryption only. Vault encryption, inspection and
/// import remain exclusively in Secrets.
final class KeyServerRepositoryImpl implements KeyServerRepository {
  final client.KeyServer _server;
  final HttpClient _transport;
  final Future<void> Function() _releaseRoute;
  final TorConnectFailure? Function()? _takeConnectFailure;
  @override
  final Duration operationTimeout;
  Future<void>? _closing;

  KeyServerRepositoryImpl({
    required Uri server,
    required HttpClient transport,
    required this._releaseRoute,
    this._takeConnectFailure,
    required this.operationTimeout,
  }) : _server = client.KeyServer(address: server, client: transport),
       _transport = transport;

  @override
  Future<Result<void, RecoverBullFailure>> probe() => _guard(() async {
    await _server.infos();
  }, probe: true);

  @override
  Future<Result<void, RecoverBullFailure>> store(
    EncryptedVault vault,
    String password,
    VaultKey key,
  ) => _guard(
    () => _server.storeBackupKey(
      backupId: hex.decode(vault.id),
      password: utf8.encode(password),
      salt: hex.decode(vault.salt),
      backupKey: hex.decode(key.hex),
    ),
  );

  @override
  Future<Result<VaultKeyFetch, RecoverBullFailure>> fetch(
    EncryptedVault vault,
    String password,
  ) => _guard(
    () async => _fetchResult(
      await _server.fetchBackupKeyWithStatus(
        backupId: hex.decode(vault.id),
        password: utf8.encode(password),
        salt: hex.decode(vault.salt),
      ),
    ),
    targeted: true,
  );

  @override
  Future<Result<VaultKeyFetch, RecoverBullFailure>> trash(
    EncryptedVault vault,
    String password,
  ) => _guard(
    () async => _fetchResult(
      await _server.trashBackupKeyWithStatus(
        backupId: hex.decode(vault.id),
        password: utf8.encode(password),
        salt: hex.decode(vault.salt),
      ),
    ),
    targeted: true,
  );

  @override
  Future<Result<AttemptSnapshot, RecoverBullFailure>> attempts(
    Set<String> digests,
  ) => _guard(() async {
    // A cold-start-only check has no need for a persistent ETag. Always request
    // a fresh projection: newly discovered digests cannot inherit a cached 304.
    final snapshot = await _server.attempts(backupIdHashes: digests.toList());
    if (snapshot is! client.AttemptsModified) {
      throw const FormatException('Missing attempt snapshot');
    }
    return AttemptSnapshot(
      collectionStartedAt: snapshot.collectionStartedAt,
      entries: {
        for (final entry in snapshot.matchingEntries)
          if (digests.contains(entry.idHash))
            entry.idHash: AttemptObservation(
              attempts: entry.totalAttempts,
              requests: entry.totalRequests,
              failures: entry.failedAttempts,
              windowStartedAt: entry.windowStartedAt,
            ),
      },
    );
  });

  VaultKeyFetch _fetchResult(client.FetchBackupKeyResult result) {
    final status = result.attemptStatus;
    return VaultKeyFetch(
      VaultKey(hex.encode(result.backupKey)),
      status == null
          ? null
          : AttemptObservation(
              attempts: status.totalAttempts,
              requests: status.totalRequests,
              failures: status.failedAttempts,
              windowStartedAt: status.windowStartedAt,
              resetsAt: status.resetsAt,
            ),
    );
  }

  Future<Result<T, RecoverBullFailure>> _guard<T>(
    Future<T> Function() operation, {
    bool probe = false,
    bool targeted = false,
  }) async {
    if (_closing != null) return const Err(VaultCancelledFailure());
    _takeConnectFailure?.call();
    try {
      final value = await operation().timeout(operationTimeout);
      log.fine('recoverbull.server.operation.completed');
      return Ok(value);
    } on client.KeyServerException catch (error) {
      // infos() wraps parsing and transport exceptions in a code-less client
      // exception. Preserve the SOCKS cause first, then classify a received
      // malformed /info response as badResponse (the develop contract).
      final status = error.code;
      final failure = switch (_takeConnectFailure?.call()) {
        final connect? => _connectFailure(connect),
        null => switch (status) {
          401 => const KeyServerFailure(KeyServerFailureKind.credentials),
          429 when targeted => KeyServerFailure(
            KeyServerFailureKind.locked,
            retryAfter: error.retryAfter,
          ),
          final int status
              when status >= 400 && status < 500 && status != 429 =>
            const KeyServerFailure(KeyServerFailureKind.rejected),
          final int status => KeyServerFailure(
            KeyServerFailureKind.unavailable,
            retryAfter: error.retryAfter,
            cause: KeyServerUnreachableCause.httpError,
            httpStatus: status,
          ),
          null => KeyServerFailure(
            probe
                ? KeyServerFailureKind.badResponse
                : KeyServerFailureKind.unavailable,
            cause: KeyServerUnreachableCause.badResponse,
          ),
        },
      };
      _logFailure(failure);
      return Err(failure);
    } on TimeoutException {
      final failure = switch (_takeConnectFailure?.call()) {
        final connect? => _connectFailure(connect),
        null => const KeyServerFailure(
          KeyServerFailureKind.timeout,
          cause: KeyServerUnreachableCause.circuitTimeout,
        ),
      };
      _logFailure(failure);
      return Err(failure);
    } on FormatException {
      const failure = KeyServerFailure(
        KeyServerFailureKind.badResponse,
        cause: KeyServerUnreachableCause.badResponse,
      );
      _logFailure(failure);
      return const Err(failure);
    } on Exception {
      final failure = switch (_takeConnectFailure?.call()) {
        final connect? => _connectFailure(connect),
        null => const KeyServerFailure(KeyServerFailureKind.unavailable),
      };
      _logFailure(failure);
      return Err(failure);
    }
  }

  static KeyServerFailure _connectFailure(TorConnectFailure failure) =>
      switch (failure) {
        TorConnectFailure.timeout => const KeyServerFailure(
          KeyServerFailureKind.timeout,
          cause: KeyServerUnreachableCause.circuitTimeout,
        ),
        TorConnectFailure.torNetworkUnreachable => const KeyServerFailure(
          KeyServerFailureKind.unavailable,
          cause: KeyServerUnreachableCause.torNetworkUnreachable,
        ),
        TorConnectFailure.hostUnreachable => const KeyServerFailure(
          KeyServerFailureKind.unavailable,
          cause: KeyServerUnreachableCause.onionUnreachable,
        ),
        TorConnectFailure.refused => const KeyServerFailure(
          KeyServerFailureKind.unavailable,
          cause: KeyServerUnreachableCause.connectionRefused,
        ),
        TorConnectFailure.proxyUnreachable => const KeyServerFailure(
          KeyServerFailureKind.unavailable,
          cause: KeyServerUnreachableCause.proxyGone,
        ),
        TorConnectFailure.other => const KeyServerFailure(
          KeyServerFailureKind.unavailable,
        ),
      };

  static void _logFailure(KeyServerFailure failure) => log.warning(
    'recoverbull.server.operation.failed category=${failure.kind.name}'
    ' cause=${failure.cause?.name ?? 'unknown'}'
    '${failure.httpStatus == null ? '' : ' status=${failure.httpStatus}'}',
  );

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _transport.close(force: true);
    try {
      await _releaseRoute();
    } on Exception {
      log.warning('recoverbull.server.route.cleanup.failed');
    }
  }
}
