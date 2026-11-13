import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
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
  final KeyServerFailureKind? Function()? _takeConnectFailure;
  final Duration timeout;
  Future<void>? _closing;

  KeyServerRepositoryImpl({
    required Uri server,
    required HttpClient transport,
    required this._releaseRoute,
    this._takeConnectFailure,
    this.timeout = const Duration(seconds: 75),
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
      final value = await operation().timeout(timeout);
      log.fine('recoverbull.server.operation.completed');
      return Ok(value);
    } on client.KeyServerException catch (error) {
      // infos() wraps parsing and transport exceptions in a code-less client
      // exception. Preserve the SOCKS cause first, then classify a received
      // malformed /info response as badResponse (the develop contract).
      final kind =
          _takeConnectFailure?.call() ??
          switch (error.code) {
            401 => KeyServerFailureKind.credentials,
            429 when targeted => KeyServerFailureKind.locked,
            429 => KeyServerFailureKind.unavailable,
            final int status when status >= 400 && status < 500 =>
              KeyServerFailureKind.rejected,
            null when probe => KeyServerFailureKind.badResponse,
            _ => KeyServerFailureKind.unavailable,
          };
      log.warning('recoverbull.server.operation.failed category=${kind.name}');
      return Err(KeyServerFailure(kind, retryAfter: error.retryAfter));
    } on TimeoutException {
      return const Err(KeyServerFailure(KeyServerFailureKind.timeout));
    } on FormatException {
      return const Err(KeyServerFailure(KeyServerFailureKind.badResponse));
    } on Exception {
      return const Err(KeyServerFailure(KeyServerFailureKind.unavailable));
    }
  }

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
