import 'dart:io';

import 'package:bull_payjoin/src/domain/payjoin_regtest_profile.dart';
import 'package:bull_payjoin/src/engine/payjoin_regtest_transport.dart';

import 'package:bull_payjoin/src/data/local_payjoin_datasource.dart';
import 'package:bull_payjoin/src/data/payjoin_cutover.dart';
import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/data/payjoin_policy_store.dart';
import 'package:bull_payjoin/src/domain/payjoin_failure.dart';
import 'package:bull_payjoin/src/domain/payjoin_policy.dart';
import 'package:bull_payjoin/src/domain/payjoin_ports.dart';
import 'package:bull_payjoin/src/domain/payjoin_requests.dart';
import 'package:bull_payjoin/src/domain/payjoin_session.dart';
import 'package:bull_payjoin/src/engine/payjoin_ownership.dart';
import 'package:bull_payjoin/src/engine/payjoin.dart' as engine;
import 'package:bull_payjoin/src/engine/payjoin_engine.dart';
import 'package:bull_payjoin/src/engine/payjoin_engine_exception.dart';
import 'package:bull_payjoin/src/engine/payjoin_fee_cap.dart';
import 'package:bull_payjoin/src/engine/payjoin_logger.dart' as logger;
import 'package:bull_payjoin/src/engine/pdk_payjoin_datasource.dart';
import 'package:bull_payjoin/src/public/payjoin.dart';
import 'package:bull_payjoin/src/public/payjoin_lifecycle.dart';
import 'package:bull_payjoin/src/public/payjoin_roles.dart';
import 'package:dio/dio.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:payjoin/http.dart' show fetchOhttpKeys;
import 'package:primitives/primitives.dart';
import 'package:synchronized/synchronized.dart';

Future<Result<PayjoinLifecycle, PayjoinFailure>> openPayjoin({
  required RuntimeAdmission admission,
  required PayjoinCutover productionCutover,
  required PayjoinCutover regtestCutover,
  required PayjoinWalletPort wallet,
  required PayjoinBlockchainPort blockchain,
  required PayjoinFeesPort fees,
  required PayjoinTransactionPort transactions,
  required PayjoinLabelsPort labels,
  required PayjoinLogPort log,
  required PayjoinCodecPort codec,
  required PayjoinInputAdmission admitInputs,
  PayjoinRegtestProfile? regtestProfile,
  RegtestHostProfile? regtestHostProfile,
  Future<bool> Function()? isCurrent,
}) => openPayjoinWithStorage(
  openStorage: (regtest) async {
    final cutover = regtest ? regtestCutover : productionCutover;
    final opened = await cutover.open(admission);
    if (opened case Ok(:final value)) {
      return Ok((database: value.database, close: value.handle.close));
    }
    return const Err(
      PayjoinStorageFailure('Could not open admitted Payjoin storage'),
    );
  },
  wallet: wallet,
  blockchain: blockchain,
  fees: fees,
  transactions: transactions,
  labels: labels,
  log: log,
  codec: codec,
  admitInputs: admitInputs,
  requirePreparedOriginal: true,
  regtestProfile: regtestProfile,
  regtestHostProfile: regtestHostProfile,
  isCurrent: isCurrent,
);

typedef PayjoinRuntimeStorage = ({
  PayjoinDatabase database,
  Future<void> Function() close,
});

Future<Result<PayjoinLifecycle, PayjoinFailure>> openPayjoinWithStorage({
  required Future<Result<PayjoinRuntimeStorage, PayjoinFailure>> Function(bool)
  openStorage,
  required PayjoinWalletPort wallet,
  required PayjoinBlockchainPort blockchain,
  required PayjoinFeesPort fees,
  required PayjoinTransactionPort transactions,
  required PayjoinLabelsPort labels,
  required PayjoinLogPort log,
  required PayjoinCodecPort codec,
  PayjoinInputAdmission? admitInputs,
  bool requirePreparedOriginal = false,
  PayjoinRegtestProfile? regtestProfile,
  RegtestHostProfile? regtestHostProfile,
  Future<bool> Function()? isCurrent,
}) async {
  // Scoped to this runtime rather than held in a library global: two runtimes
  // in one isolate (a retried open, a test) would otherwise overwrite each
  // other's destination, and the order of `openPayjoin` calls would silently
  // decide where a session's failures are reported.
  final payjoinLog = logger.PayjoinLogger(log);
  final host = regtestHostProfile ?? regtestProfile?.hostProfile;
  final regtest = host != null;
  PayjoinFailure? unavailable;
  if (host != null && regtestProfile == null) {
    try {
      regtestProfile = PayjoinRegtestProfile.fromBuildEnvironment(
        hostProfile: host,
      );
    } on FormatException {
      unavailable = const PayjoinUnavailableFailure(
        'Regtest Payjoin trust is unavailable',
      );
    }
  }
  PayjoinRegtestTransport? fixtureTransport;
  final opened = await openStorage(regtest);
  if (opened case Err(:final failure)) return Err(failure);
  final (database: database, close: closeDatabase) =
      (opened as Ok<PayjoinRuntimeStorage, PayjoinFailure>).value;

  try {
    if (regtestProfile != null) {
      try {
        fixtureTransport = PayjoinRegtestTransport(
          profile: regtestProfile,
          environment: NetworkEnv.regtest,
          isCurrent: isCurrent,
        );
      } on TlsException {
        unavailable = const PayjoinUnavailableFailure(
          'Regtest Payjoin trust is unavailable',
        );
      }
    }
    final transport = fixtureTransport;
    final current = unavailable == null ? isCurrent : () async => false;
    final local = LocalPayjoinDatasource(db: database);
    final policy = PayjoinPolicyStore(database);
    await policy.load();
    final dio =
        transport?.createDio() ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 35),
          ),
        );
    if (transport == null && current != null) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            try {
              if (!await current()) {
                throw const PayjoinRuntimeInactiveException();
              }
              handler.next(options);
            } on Exception {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: const PayjoinRuntimeInactiveException(),
                ),
              );
            }
          },
        ),
      );
    }
    final pdk = PdkPayjoinDatasource(
      isCurrent: current,
      networkOverride: regtest ? BitcoinNetwork.regtest : null,
      servers: regtestProfile?.servers,
      ohttpKeysFetcher: transport?.fetchOhttpKeys ?? fetchOhttpKeys,
      dio: dio,
      log: payjoinLog,
      codec: codec,
    );
    final engine = PayjoinRepositoryImpl(
      regtest: regtest,
      isCurrent: current,
      localPayjoinDatasource: local,
      pdkPayjoinDatasource: pdk,
      log: payjoinLog,
      wallet: wallet,
      blockchain: blockchain,
      transactions: transactions,
      policy: policy,
      labels: labels,
      codec: codec,
      admitInputs: admitInputs,
    );
    final roles = _PayjoinRoles(
      engine,
      policy,
      wallet,
      fees,
      payjoinLog,
      codec,
      regtest: regtest,
      isCurrent: current,
      requirePreparedOriginal: requirePreparedOriginal,
    );
    final blocked = unavailable;
    final unavailableRoles = blocked == null
        ? null
        : Payjoin.unavailable(blocked);
    final publicPayjoin = unavailableRoles == null
        ? roles.payjoin
        : Payjoin(
            sender: unavailableRoles.sender,
            receiver: unavailableRoles.receiver,
            sessions: roles.payjoin.sessions,
            policy: roles.payjoin.policy,
            diagnostics: unavailableRoles.diagnostics,
          );
    return Ok(
      _PayjoinLifecycle(
        closeDatabase,
        engine,
        publicPayjoin,
        transport,
        blocked,
      ),
    );
  } catch (error, trace) {
    // No quarantine-and-retry here: with the import's row-level quarantine,
    // a post-open throw is an IO/disk problem or a bug — a fresh file would
    // not help and would needlessly discard readable payjoin history.
    payjoinLog.severe(
      code: PayjoinLogCode.migrationFailure,
      error: error,
      trace: trace,
    );
    await fixtureTransport?.close();
    await closeDatabase();
    return const Err(
      PayjoinMigrationFailure('Could not open or migrate Payjoin storage'),
    );
  }
}

final class _PayjoinLifecycle implements PayjoinLifecycle {
  final Future<void> Function() _closeDatabase;
  final PayjoinRepositoryImpl _engine;
  final PayjoinRegtestTransport? _transport;
  final PayjoinFailure? _unavailable;

  @override
  final Payjoin payjoin;

  _PayjoinLifecycle(
    this._closeDatabase,
    this._engine,
    this.payjoin,
    this._transport,
    this._unavailable,
  );

  @override
  Future<Result<void, PayjoinFailure>> resume() async {
    if (_unavailable case final failure?) return Err(failure);
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
    await _transport?.close();
    await _closeDatabase();
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
  Future<Result<String?, PayjoinFailure>> visibleTransaction(String id);
  Future<Result<PayjoinSession, PayjoinFailure>> retryProposal(String id);
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
  Future<Result<List<PayjoinInputReservation>, PayjoinFailure>>
  inputReservations();
  Future<Result<PayjoinPolicy, PayjoinFailure>> load();
  Stream<Result<PayjoinPolicy, PayjoinFailure>> watchPolicy();
  Future<Result<PayjoinPolicy, PayjoinFailure>> setActionEnabled(
    PayjoinAction action, {
    required bool enabled,
  });
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
  final logger.PayjoinLogger _log;
  final PayjoinCodecPort _codec;
  final bool _regtest;
  final bool _requirePreparedOriginal;
  final Future<bool> Function()? _isCurrent;
  final Lock _policyMutationLock = Lock();

  late final Payjoin payjoin = Payjoin(
    sender: _SenderRole(this),
    receiver: _ReceiverRole(this),
    sessions: _SessionsRole(this),
    policy: _PolicyRole(this),
    diagnostics: _DiagnosticsRole(this),
  );

  _PayjoinRoles(
    this._engine,
    this._policy,
    this._wallet,
    this._fees,
    this._log,
    this._codec, {
    this._regtest = false,
    required this._requirePreparedOriginal,
    this._isCurrent,
  });

  PayjoinSession _toSession(engine.Payjoin value) => _mapSession(
    value,
    codec: _codec,
    networkOverride: _regtest ? BitcoinNetwork.regtest : null,
    fallbackAvailableAt: _engine.receiverFallbackAvailableAt(value.id),
    spendFailure: _engine.proposalSpendFailure(value.id),
  );

  @override
  Future<Result<PayjoinSenderSession, PayjoinFailure>> startSender(
    StartPayjoinSender request,
  ) async {
    if (_requirePreparedOriginal && request.preparedOriginal == null) {
      return const Err(PayjoinInvalidInputFailure('Reviewed spend required'));
    }
    if (_regtest != (request.network == BitcoinNetwork.regtest)) {
      return const Err(
        PayjoinInvalidInputFailure('Payjoin runtime network mismatch'),
      );
    }
    late final PayjoinPolicy policy;
    try {
      policy = await _policy.load();
    } catch (_) {
      return const Err(PayjoinStorageFailure('Policy lookup failed'));
    }
    if (_isCurrent case final current? when !await current()) {
      return const Err(
        PayjoinUnavailableFailure('Payjoin runtime family changed'),
      );
    }
    late final Duration lifetime;
    try {
      lifetime = _lifetime(policy, request.expiresAt);
    } on ArgumentError {
      return const Err(PayjoinInvalidInputFailure('Invalid sender expiry'));
    }
    late final String signed;
    try {
      signed =
          request.preparedOriginal?.signedPsbt ??
          await _engineWalletSign(request);
    } on PayjoinSpendBlockedException catch (blocked) {
      return Err(PayjoinSpendBlockedFailure(busy: blocked.busy));
    } catch (error, trace) {
      _log.warning(
        code: PayjoinLogCode.signingFailure,
        role: PayjoinLogRole.sender,
        error: error,
        trace: trace,
      );
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
        admitOriginal: request.preparedOriginal?.admit,
      );
      return Ok(_toSession(session) as PayjoinSenderSession);
    } on PayjoinSenderKeptException catch (error, trace) {
      _log.warning(
        code: PayjoinLogCode.sessionStartFailed,
        role: PayjoinLogRole.sender,
        error: error.cause,
        trace: trace,
      );
      if (error.publicationUnknown) {
        return Err(PayjoinPublicationUnknownFailure(error.originalTxId));
      }
      return Err(
        PayjoinSenderKeptFailure(
          error.originalTxId,
          'Sender start failed; session kept',
        ),
      );
    } on PayjoinSpendBlockedException catch (blocked) {
      return Err(PayjoinSpendBlockedFailure(busy: blocked.busy));
    } on PayjoinRuntimeInactiveException {
      return const Err(
        PayjoinUnavailableFailure('Payjoin runtime family changed'),
      );
    } catch (error, trace) {
      // The failure handed back is deliberately generic; without this the
      // cause of a payment falling back to a plain transaction is lost.
      _log.warning(
        code: PayjoinLogCode.sessionStartFailed,
        role: PayjoinLogRole.sender,
        error: error,
        trace: trace,
      );
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
    if (_regtest != (request.network == BitcoinNetwork.regtest)) {
      return const Err(
        PayjoinInvalidInputFailure('Payjoin runtime network mismatch'),
      );
    }
    late final PayjoinPolicy policy;
    try {
      policy = await _policy.load();
    } catch (_) {
      return const Err(PayjoinStorageFailure('Policy lookup failed'));
    }
    if (_isCurrent case final current? when !await current()) {
      return const Err(
        PayjoinUnavailableFailure('Payjoin runtime family changed'),
      );
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
        isTrade: request.isTrade,
      );
      return Ok(_toSession(session) as PayjoinReceiverSession);
    } on PayjoinRuntimeInactiveException {
      return const Err(
        PayjoinUnavailableFailure('Payjoin runtime family changed'),
      );
    } catch (error, trace) {
      _log.warning(
        code: PayjoinLogCode.sessionStartFailed,
        role: PayjoinLogRole.receiver,
        error: error,
        trace: trace,
      );
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
      return (await _engine.tryBroadcastOriginalTransaction(current))
          .map(_toSession);
    } on PayjoinSpendBlockedException catch (blocked) {
      return Err(PayjoinSpendBlockedFailure(busy: blocked.busy));
    } catch (_) {
      return const Err(PayjoinBroadcastFailure('Broadcast failed'));
    }
  }

  @override
  Future<Result<PayjoinSession, PayjoinFailure>> retryProposal(
    String id,
  ) async {
    try {
      return (await _engine.retryProposal(id)).map(_toSession);
    } catch (_) {
      return const Err(PayjoinStorageFailure('Proposal retry failed'));
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
  Future<Result<String?, PayjoinFailure>> visibleTransaction(
    String sessionId,
  ) async {
    try {
      return await _engine.visibleCompetingTransaction(sessionId);
    } catch (_) {
      return const Err(
        PayjoinUnavailableFailure('Could not check transaction visibility'),
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
      await _engine.settleAllReceivers();
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
  Future<Result<List<PayjoinInputReservation>, PayjoinFailure>>
  inputReservations() async {
    try {
      return Ok(await _engine.getInputReservations());
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
  Future<Result<PayjoinPolicy, PayjoinFailure>> setActionEnabled(
    PayjoinAction action, {
    required bool enabled,
  }) async {
    return _policyMutationLock.synchronized(() async {
      late final PayjoinPolicy saved;
      try {
        saved = await _policy.setActionEnabled(action, enabled: enabled);
      } catch (_) {
        return const Err(PayjoinStorageFailure('Policy update failed'));
      }
      // Only receivers have a policy gate after creation. A sender session
      // has committed the payment and must resolve, so turning off send or
      // sell only stops new ones.
      final gatesReceivers =
          action == PayjoinAction.receive || action == PayjoinAction.buy;
      if (!enabled && gatesReceivers) {
        try {
          await _engine.settleReceiversNotPermittedBy(saved);
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
  Future<Result<PayjoinSession, PayjoinFailure>> retryProposal(String id) =>
      _runtime.retryProposal(id);

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

  @override
  Future<Result<String?, PayjoinFailure>> visibleTransaction(
    String sessionId,
  ) => _runtime.visibleTransaction(sessionId);

  @override
  Future<Result<List<PayjoinInputReservation>, PayjoinFailure>>
  inputReservations() => _runtime.inputReservations();
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
  Future<Result<PayjoinPolicy, PayjoinFailure>> setActionEnabled(
    PayjoinAction action, {
    required bool enabled,
  }) => _runtime.setActionEnabled(action, enabled: enabled);

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

PayjoinSession _mapSession(
  engine.Payjoin value, {
  required PayjoinCodecPort codec,
  BitcoinNetwork? networkOverride,
  DateTime? fallbackAvailableAt,
  PayjoinSpendBlockedFailure? spendFailure,
}) {
  final network =
      networkOverride ??
      (value.isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet);
  final status = PayjoinStatus.values.byName(value.status.name);
  final ownership = _deriveOwnership(
    value,
    codec,
    networkOverride: networkOverride,
  );
  return switch (value) {
    engine.PayjoinSender() => PayjoinSenderSession(
      spendFailure: spendFailure,
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
      fallbackAvailableAt: fallbackAvailableAt,
      ownership: ownership,
    ),
  };
}

PayjoinOwnership? _deriveOwnership(
  engine.Payjoin payjoin,
  PayjoinCodecPort codec, {
  BitcoinNetwork? networkOverride,
}) {
  final proposalPsbt = payjoin.proposalPsbt;
  final txId = payjoin.txId;
  if (proposalPsbt == null || txId == null) return null;

  try {
    final proposal = codec.decodePsbt(proposalPsbt);
    if (proposal.txid != txId) return null;

    final (original, bip21) = switch (payjoin) {
      engine.PayjoinSender(:final originalPsbt, :final uri) => (
        codec.decodePsbt(originalPsbt),
        uri,
      ),
      engine.PayjoinReceiver(:final originalTxBytes, :final pjUri) => (
        originalTxBytes == null
            ? null
            : codec.decodeTransaction(originalTxBytes),
        pjUri,
      ),
    };
    if (original == null || original.txid != payjoin.originalTxId) return null;

    final paymentScript = paymentScriptFromBip21(
      bip21,
      codec: codec,
      isTestnet: payjoin.isTestnet,
      networkOverride: networkOverride,
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
