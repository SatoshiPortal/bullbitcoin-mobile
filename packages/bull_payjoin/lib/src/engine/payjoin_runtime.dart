import 'dart:io';

import 'package:bull_payjoin/src/data/local_payjoin_datasource.dart';
import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/data/payjoin_migration.dart';
import 'package:bull_payjoin/src/data/payjoin_policy_store.dart';
import 'package:bull_payjoin/src/domain/payjoin_failure.dart';
import 'package:bull_payjoin/src/domain/payjoin_policy.dart';
import 'package:bull_payjoin/src/domain/payjoin_ports.dart';
import 'package:bull_payjoin/src/domain/payjoin_requests.dart';
import 'package:bull_payjoin/src/domain/payjoin_session.dart';
import 'package:bull_payjoin/src/engine/bitcoin_tx.dart';
import 'package:bull_payjoin/src/engine/payjoin.dart' as engine;
import 'package:bull_payjoin/src/engine/payjoin_engine.dart';
import 'package:bull_payjoin/src/engine/payjoin_fee_cap.dart';
import 'package:bull_payjoin/src/engine/payjoin_logger.dart' as logger;
import 'package:bull_payjoin/src/engine/pdk_payjoin_datasource.dart';
import 'package:bull_payjoin/src/public/payjoin.dart';
import 'package:bull_payjoin/src/public/payjoin_lifecycle.dart';
import 'package:bull_payjoin/src/public/payjoin_roles.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';
import 'package:synchronized/synchronized.dart';

Future<Result<PayjoinLifecycle, PayjoinFailure>> openPayjoin({
  required String databasePath,
  required PayjoinWalletPort wallet,
  required PayjoinBlockchainPort blockchain,
  required PayjoinFeesPort fees,
  required PayjoinTransactionPort transactions,
  required PayjoinLabelsPort labels,
  required PayjoinLegacyDataPort legacyData,
  required PayjoinLogPort log,
}) async {
  // Scoped to this runtime rather than held in a library global: two runtimes
  // in one isolate (a retried open, a test) would otherwise overwrite each
  // other's destination, and the order of `openPayjoin` calls would silently
  // decide where a session's failures are reported.
  final payjoinLog = logger.PayjoinLogger(log);
  var database = await _tryOpenDatabase(databasePath, payjoinLog);
  if (database == null) {
    // Self-heal: a corrupt database file or a schema downgrade would
    // otherwise fail every open retry identically — and because
    // reservedOutpoints() gates coin selection, that bricks every bitcoin
    // send in the app until reinstall. Move the unreadable file aside (kept
    // for forensics) and retry once with a fresh database; the legacy import
    // below re-populates it from the root database's legacy tables. Sessions
    // created after that import are lost, but their funds are not: a
    // sender's counterparty still holds the original and can broadcast it,
    // and a receiver's sender owns their own fallback.
    database = await _quarantineAndReopenDatabase(databasePath, payjoinLog);
    if (database == null) {
      return const Err(
        PayjoinMigrationFailure('Could not open or migrate Payjoin storage'),
      );
    }
  }

  try {
    await importLegacyPayjoinData(database, legacyData, log: log);
    final local = LocalPayjoinDatasource(db: database);
    final policy = PayjoinPolicyStore(database);
    await policy.load();
    final pdk = PdkPayjoinDatasource(
      dio: Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 35),
        ),
      ),
      log: payjoinLog,
    );
    final engine = PayjoinRepositoryImpl(
      localPayjoinDatasource: local,
      pdkPayjoinDatasource: pdk,
      log: payjoinLog,
      wallet: wallet,
      blockchain: blockchain,
      transactions: transactions,
      policy: policy,
      labels: labels,
    );
    final roles = _PayjoinRoles(engine, policy, wallet, fees);
    return Ok(_PayjoinLifecycle(database, engine, roles.payjoin));
  } catch (error, trace) {
    // No quarantine-and-retry here: with the import's row-level quarantine,
    // a post-open throw is an IO/disk problem or a bug — a fresh file would
    // not help and would needlessly discard readable payjoin history.
    payjoinLog.severe(
      message: 'Could not open or migrate Payjoin storage',
      code: PayjoinLogCode.migrationFailure,
      error: error,
      trace: trace,
    );
    await database.close();
    return const Err(
      PayjoinMigrationFailure('Could not open or migrate Payjoin storage'),
    );
  }
}

Future<PayjoinDatabase?> _tryOpenDatabase(
  String databasePath,
  logger.PayjoinLogger payjoinLog,
) async {
  try {
    final database = PayjoinDatabase.open(databasePath);
    // Force the lazy open NOW: drift spawns the background isolate, opens
    // the file and runs schema migrations on the first statement, so a
    // corrupt file or a schema downgrade surfaces here rather than
    // mid-import.
    await database.customSelect('SELECT 1').getSingle();
    return database;
  } catch (error, trace) {
    payjoinLog.severe(
      message: 'Could not open Payjoin storage',
      code: PayjoinLogCode.migrationFailure,
      error: error,
      trace: trace,
    );
    return null;
  }
}

Future<PayjoinDatabase?> _quarantineAndReopenDatabase(
  String databasePath,
  logger.PayjoinLogger payjoinLog,
) async {
  try {
    final suffix =
        '.unreadable-${DateTime.now().toUtc().millisecondsSinceEpoch}';
    // The WAL and SHM siblings belong to the unreadable database: leaving
    // them in place would let SQLite replay them into the FRESH database
    // created at the same path. Rename all three together.
    for (final path in [
      databasePath,
      '$databasePath-wal',
      '$databasePath-shm',
    ]) {
      final file = File(path);
      if (file.existsSync()) await file.rename('$path$suffix');
    }
  } catch (error, trace) {
    payjoinLog.severe(
      message: 'Could not quarantine unreadable Payjoin storage',
      code: PayjoinLogCode.migrationFailure,
      error: error,
      trace: trace,
    );
    return null;
  }
  payjoinLog.warning(
    '',
    code: PayjoinLogCode.migrationFailure,
    error: StateError(
      'Moved unreadable Payjoin database aside and reopened a fresh one; '
      'sessions created after the legacy import were lost',
    ),
  );
  return _tryOpenDatabase(databasePath, payjoinLog);
}

final class _PayjoinLifecycle implements PayjoinLifecycle {
  final PayjoinDatabase _database;
  final PayjoinRepositoryImpl _engine;

  @override
  final Payjoin payjoin;

  _PayjoinLifecycle(this._database, this._engine, this.payjoin);

  @override
  Future<Result<void, PayjoinFailure>> resume() async {
    try {
      await _engine.resumePayjoinsOnStartup();
      return const Ok(null);
    } catch (_) {
      return const Err(
        PayjoinUnexpectedFailure('Could not resume Payjoin sessions'),
      );
    }
  }

  @override
  Future<void> dispose() async {
    await _engine.dispose();
    await _database.close();
  }
}

abstract interface class _PayjoinRuntimeContract {
  Future<Result<PayjoinSenderSession, PayjoinFailure>> startSender(
    StartPayjoinSender request,
  );
  Future<Result<PayjoinReceiverSession, PayjoinFailure>> startReceiver(
    StartPayjoinReceiver request,
  );
  Future<Result<PayjoinSession, PayjoinFailure>> broadcastOriginal(String id);
  Future<Result<bool, PayjoinFailure>> canBroadcastOriginal(String id);
  Future<Result<void, PayjoinFailure>> cancel(String id);
  Future<Result<void, PayjoinFailure>> disableAll();
  Future<Result<PayjoinSession?, PayjoinFailure>> byId(String id);
  Future<Result<List<PayjoinSession>, PayjoinFailure>> byTransactionId(
    String transactionId,
  );
  Future<Result<List<PayjoinSession>, PayjoinFailure>> list(
    PayjoinSessionFilter filter,
  );
  Stream<Result<PayjoinSession, PayjoinFailure>> watchSessions({
    Set<String>? sessionIds,
  });
  Future<Result<Set<Outpoint>, PayjoinFailure>> reservedOutpoints();
  Future<Result<PayjoinPolicy, PayjoinFailure>> load();
  Stream<Result<PayjoinPolicy, PayjoinFailure>> watchPolicy();
  Future<Result<PayjoinPolicy, PayjoinFailure>> setEnabled(bool enabled);
  Future<Result<PayjoinPolicy, PayjoinFailure>> setMinimumAmount(Sats amount);
  Future<Result<PayjoinPolicy, PayjoinFailure>> setSessionLifetime(
    Duration lifetime,
  );
  Future<Result<PayjoinRelayHealth, PayjoinFailure>> relayHealth();
}

final class _PayjoinRoles implements _PayjoinRuntimeContract {
  final PayjoinRepositoryImpl _engine;
  final PayjoinPolicyStore _policy;
  final PayjoinWalletPort _wallet;
  final PayjoinFeesPort _fees;
  final Lock _policyMutationLock = Lock();

  late final Payjoin payjoin = Payjoin(
    sender: _SenderRole(this),
    receiver: _ReceiverRole(this),
    sessions: _SessionsRole(this),
    policy: _PolicyRole(this),
    diagnostics: _DiagnosticsRole(this),
  );

  _PayjoinRoles(this._engine, this._policy, this._wallet, this._fees);

  @override
  Future<Result<PayjoinSenderSession, PayjoinFailure>> startSender(
    StartPayjoinSender request,
  ) async {
    late final PayjoinPolicy policy;
    try {
      policy = await _policy.load();
    } catch (_) {
      return const Err(PayjoinStorageFailure('Policy lookup failed'));
    }
    late final Duration lifetime;
    try {
      lifetime = _lifetime(policy, request.expiresAt);
    } on ArgumentError {
      return const Err(PayjoinInvalidInputFailure('Invalid sender expiry'));
    }
    late final String signed;
    try {
      signed = await _engineWalletSign(request);
    } catch (_) {
      return const Err(PayjoinSigningFailure('Sender signing failed'));
    }
    try {
      final session = await _engine.createPayjoinSender(
        walletId: request.walletId,
        isTestnet: !request.network.isMainnet,
        bip21: request.bip21Uri,
        originalPsbt: signed,
        amountSat: request.amount.value.toInt(),
        networkFeesSatPerVb: request.feeRate.satsPerVbyte,
        expireAfterSec: lifetime.inSeconds,
      );
      return Ok(_toSession(session) as PayjoinSenderSession);
    } catch (_) {
      return const Err(PayjoinProtocolRejectedFailure('Sender start failed'));
    }
  }

  Future<String> _engineWalletSign(StartPayjoinSender request) {
    return _wallet.signPsbt(
      walletId: request.walletId,
      network: request.network,
      psbt: request.unsignedOriginalPsbt,
    );
  }

  @override
  Future<Result<PayjoinReceiverSession, PayjoinFailure>> startReceiver(
    StartPayjoinReceiver request,
  ) async {
    late final PayjoinPolicy policy;
    try {
      policy = await _policy.load();
    } catch (_) {
      return const Err(PayjoinStorageFailure('Policy lookup failed'));
    }
    late final Duration lifetime;
    try {
      lifetime = _lifetime(policy, request.expiresAt);
    } on ArgumentError {
      return const Err(PayjoinInvalidInputFailure('Invalid receiver expiry'));
    }
    try {
      final session = await _engine.createPayjoinReceiver(
        walletId: request.walletId,
        address: request.address,
        isTestnet: !request.network.isMainnet,
        maxFeeRateSatPerVb: BigInt.from(
          await receiverMaxFeeRateSatPerVb(_fees, request.network),
        ),
        expireAfterSec: lifetime.inSeconds,
        amountSat: request.amount?.value.toInt(),
      );
      return Ok(_toSession(session) as PayjoinReceiverSession);
    } catch (_) {
      return const Err(PayjoinProtocolRejectedFailure('Receiver start failed'));
    }
  }

  @override
  Future<Result<PayjoinSession, PayjoinFailure>> broadcastOriginal(
    String sessionId,
  ) async {
    try {
      final current = await _engine.getPayjoinById(sessionId);
      if (current == null) {
        return const Err(PayjoinSessionNotFoundFailure('Session not found'));
      }
      return (await _engine.tryBroadcastOriginalTransaction(
        current,
      )).map(_toSession);
    } catch (_) {
      return const Err(PayjoinBroadcastFailure('Broadcast failed'));
    }
  }

  @override
  Future<Result<bool, PayjoinFailure>> canBroadcastOriginal(
    String sessionId,
  ) async {
    try {
      return Ok(await _engine.canManuallyBroadcastOriginal(sessionId));
    } catch (_) {
      return const Err(
        PayjoinUnavailableFailure('Could not check fallback availability'),
      );
    }
  }

  @override
  Future<Result<void, PayjoinFailure>> cancel(String sessionId) async {
    try {
      await _engine.cancelReceiver(sessionId);
      return const Ok(null);
    } catch (_) {
      return const Err(PayjoinInvalidSessionTransitionFailure('Cancel failed'));
    }
  }

  @override
  Future<Result<void, PayjoinFailure>> disableAll() async {
    try {
      await _engine.disableReceivers();
      return const Ok(null);
    } catch (_) {
      return const Err(
        PayjoinInvalidSessionTransitionFailure('Disable failed'),
      );
    }
  }

  @override
  Future<Result<PayjoinSession?, PayjoinFailure>> byId(String sessionId) async {
    try {
      final value = await _engine.getPayjoinById(sessionId);
      return Ok(value == null ? null : _toSession(value));
    } catch (_) {
      return const Err(PayjoinStorageFailure('Session lookup failed'));
    }
  }

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> byTransactionId(
    String transactionId,
  ) async {
    try {
      final values = await _engine.getPayjoinsByTxId(transactionId);
      return Ok(values.map(_toSession).toList());
    } catch (_) {
      return const Err(PayjoinStorageFailure('Session lookup failed'));
    }
  }

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> list(
    PayjoinSessionFilter filter,
  ) async {
    try {
      final values = await _engine.getPayjoins(
        walletId: filter.walletId,
        onlyOngoing: filter.ongoingOnly,
        network: filter.network,
      );
      return Ok(values.map(_toSession).toList());
    } catch (_) {
      return const Err(PayjoinStorageFailure('Session listing failed'));
    }
  }

  @override
  Stream<Result<PayjoinSession, PayjoinFailure>> watchSessions({
    Set<String>? sessionIds,
  }) {
    return _engine.payjoinStream
        .where((value) => sessionIds == null || sessionIds.contains(value.id))
        .map((value) => Ok<PayjoinSession, PayjoinFailure>(_toSession(value)));
  }

  @override
  Future<Result<Set<Outpoint>, PayjoinFailure>> reservedOutpoints() async {
    try {
      final values = await _engine.getUtxosFrozenByOngoingPayjoins();
      return Ok(
        values.map((value) => (txId: value.txId, vout: value.vout)).toSet(),
      );
    } catch (_) {
      return const Err(PayjoinStorageFailure('UTXO lookup failed'));
    }
  }

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> load() async {
    try {
      return Ok(await _policy.load());
    } catch (_) {
      return const Err(PayjoinStorageFailure('Policy lookup failed'));
    }
  }

  @override
  Stream<Result<PayjoinPolicy, PayjoinFailure>> watchPolicy() async* {
    try {
      await for (final value in _policy.watch()) {
        yield Ok(value);
      }
    } catch (_) {
      yield const Err(PayjoinStorageFailure('Policy watch failed'));
    }
  }

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setEnabled(bool enabled) async {
    return _policyMutationLock.synchronized(() async {
      late final PayjoinPolicy saved;
      try {
        saved = await _policy.setEnabled(enabled);
      } catch (_) {
        return const Err(PayjoinStorageFailure('Policy update failed'));
      }
      if (!enabled) {
        try {
          await _engine.disableReceivers();
        } catch (_) {
          return const Err(
            PayjoinInvalidSessionTransitionFailure(
              'Policy disabled but receivers could not settle',
            ),
          );
        }
      }
      return Ok(saved);
    });
  }

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setMinimumAmount(
    Sats amount,
  ) async {
    return _policyMutationLock.synchronized(() async {
      try {
        final current = await _policy.load();
        current.copyWith(minimumAmount: amount);
        return Ok(await _policy.setMinimumAmount(amount));
      } on ArgumentError {
        return const Err(PayjoinInvalidInputFailure('Invalid minimum amount'));
      } catch (_) {
        return const Err(PayjoinStorageFailure('Policy update failed'));
      }
    });
  }

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setSessionLifetime(
    Duration lifetime,
  ) async {
    return _policyMutationLock.synchronized(() async {
      try {
        final current = await _policy.load();
        current.copyWith(sessionLifetime: lifetime);
        return Ok(await _policy.setSessionLifetime(lifetime));
      } on ArgumentError {
        return const Err(
          PayjoinInvalidInputFailure('Invalid session lifetime'),
        );
      } catch (_) {
        return const Err(PayjoinStorageFailure('Policy update failed'));
      }
    });
  }

  @override
  Future<Result<PayjoinRelayHealth, PayjoinFailure>> relayHealth() async {
    try {
      return Ok(
        await _engine.checkOhttpRelayHealth()
            ? PayjoinRelayHealth.available
            : PayjoinRelayHealth.unavailable,
      );
    } catch (_) {
      return const Err(PayjoinRelayUnavailableFailure('Relay unavailable'));
    }
  }

  Duration _lifetime(PayjoinPolicy policy, DateTime? requestedExpiry) {
    if (requestedExpiry == null) return policy.sessionLifetime;
    final rawRequested = requestedExpiry.difference(DateTime.now());
    final requested = Duration(
      seconds:
          (rawRequested.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
          Duration.microsecondsPerSecond,
    );
    if (requested < PayjoinPolicy.minimumSessionLifetime) {
      throw ArgumentError.value(requestedExpiry, 'expiresAt');
    }
    return requested < policy.sessionLifetime
        ? requested
        : policy.sessionLifetime;
  }
}

final class _SenderRole implements PayjoinSender {
  final _PayjoinRuntimeContract _runtime;

  const _SenderRole(this._runtime);

  @override
  Future<Result<PayjoinSenderSession, PayjoinFailure>> start(
    StartPayjoinSender request,
  ) => _runtime.startSender(request);

  @override
  Future<Result<PayjoinSession, PayjoinFailure>> broadcastOriginal(String id) =>
      _runtime.broadcastOriginal(id);

  @override
  Future<Result<bool, PayjoinFailure>> canBroadcastOriginal(String id) =>
      _runtime.canBroadcastOriginal(id);
}

final class _ReceiverRole implements PayjoinReceiver {
  final _PayjoinRuntimeContract _runtime;

  const _ReceiverRole(this._runtime);

  @override
  Future<Result<PayjoinReceiverSession, PayjoinFailure>> start(
    StartPayjoinReceiver request,
  ) => _runtime.startReceiver(request);

  @override
  Future<Result<void, PayjoinFailure>> cancel(String id) => _runtime.cancel(id);

  @override
  Future<Result<void, PayjoinFailure>> disableAll() => _runtime.disableAll();
}

final class _SessionsRole implements PayjoinSessions {
  final _PayjoinRuntimeContract _runtime;

  const _SessionsRole(this._runtime);

  @override
  Future<Result<PayjoinSession?, PayjoinFailure>> byId(String id) =>
      _runtime.byId(id);

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> byTransactionId(
    String transactionId,
  ) => _runtime.byTransactionId(transactionId);

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> list(
    PayjoinSessionFilter filter,
  ) => _runtime.list(filter);

  @override
  Stream<Result<PayjoinSession, PayjoinFailure>> watch({
    Set<String>? sessionIds,
  }) => _runtime.watchSessions(sessionIds: sessionIds);

  @override
  Future<Result<Set<Outpoint>, PayjoinFailure>> reservedOutpoints() =>
      _runtime.reservedOutpoints();
}

final class _PolicyRole implements PayjoinPolicyAccess {
  final _PayjoinRuntimeContract _runtime;

  const _PolicyRole(this._runtime);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> load() => _runtime.load();

  @override
  Stream<Result<PayjoinPolicy, PayjoinFailure>> watch() =>
      _runtime.watchPolicy();

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setEnabled(bool enabled) =>
      _runtime.setEnabled(enabled);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setMinimumAmount(Sats amount) =>
      _runtime.setMinimumAmount(amount);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setSessionLifetime(
    Duration lifetime,
  ) => _runtime.setSessionLifetime(lifetime);
}

final class _DiagnosticsRole implements PayjoinDiagnostics {
  final _PayjoinRuntimeContract _runtime;

  const _DiagnosticsRole(this._runtime);

  @override
  Future<Result<PayjoinRelayHealth, PayjoinFailure>> relayHealth() =>
      _runtime.relayHealth();
}

PayjoinSession _toSession(engine.Payjoin value) {
  final network = value.isTestnet
      ? BitcoinNetwork.testnet
      : BitcoinNetwork.mainnet;
  final status = PayjoinStatus.values.byName(value.status.name);
  final ownership = _deriveOwnership(value);
  return switch (value) {
    engine.PayjoinSender() => PayjoinSenderSession(
      status: status,
      uri: value.id,
      network: network,
      walletId: value.walletId,
      createdAt: value.createdAt,
      expiresAt: value.expiresAt,
      amount: Sats.fromInt(value.amountSat),
      originalTransactionId: value.originalTxId,
      transactionId: value.txId,
      hasProposal: value.proposalPsbt != null,
      ownership: ownership,
    ),
    engine.PayjoinReceiver() => PayjoinReceiverSession(
      status: status,
      id: value.id,
      network: network,
      walletId: value.walletId,
      createdAt: value.createdAt,
      expiresAt: value.expiresAt,
      payjoinUri: value.pjUri,
      amount: value.amountSat == null ? null : Sats.fromInt(value.amountSat!),
      originalTransactionId: value.originalTxId,
      transactionId: value.txId,
      hasProposal: value.proposalPsbt != null,
      hasOriginalTransaction: value.originalTxBytes != null,
      ownership: ownership,
    ),
  };
}

PayjoinOwnership? _deriveOwnership(engine.Payjoin payjoin) {
  final proposalPsbt = payjoin.proposalPsbt;
  final txId = payjoin.txId;
  if (proposalPsbt == null || txId == null) return null;

  try {
    final proposal = BitcoinTx.fromPsbtSync(proposalPsbt);
    if (proposal.txid != txId) return null;

    final (original, bip21) = switch (payjoin) {
      engine.PayjoinSender(:final originalPsbt, :final uri) => (
        BitcoinTx.fromPsbtSync(originalPsbt),
        uri,
      ),
      engine.PayjoinReceiver(:final originalTxBytes, :final pjUri) => (
        originalTxBytes == null
            ? null
            : BitcoinTx.fromBytesSync(originalTxBytes),
        pjUri,
      ),
    };
    if (original == null || original.txid != payjoin.originalTxId) return null;

    final paymentScript = paymentScriptFromBip21(
      bip21,
      isTestnet: payjoin.isTestnet,
    );
    if (paymentScript == null) return null;
    return derivePayjoinOwnership(
      original: original,
      proposal: proposal,
      paymentScript: paymentScript,
    );
  } catch (_) {
    return null;
  }
}
