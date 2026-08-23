import 'package:bull_payjoin/src/domain/payjoin_failure.dart';
import 'package:bull_payjoin/src/domain/payjoin_policy.dart';
import 'package:bull_payjoin/src/domain/payjoin_requests.dart';
import 'package:bull_payjoin/src/domain/payjoin_session.dart';
import 'package:bull_payjoin/src/public/payjoin_roles.dart';
import 'package:primitives/primitives.dart';

final class Payjoin {
  final PayjoinSender sender;
  final PayjoinReceiver receiver;
  final PayjoinSessions sessions;
  final PayjoinPolicyAccess policy;
  final PayjoinDiagnostics diagnostics;

  const Payjoin({
    required this.sender,
    required this.receiver,
    required this.sessions,
    required this.policy,
    required this.diagnostics,
  });

  factory Payjoin.unavailable(PayjoinFailure failure) => Payjoin(
    sender: _UnavailablePayjoinSender(failure),
    receiver: _UnavailablePayjoinReceiver(failure),
    sessions: _UnavailablePayjoinSessions(failure),
    policy: _UnavailablePayjoinPolicy(failure),
    diagnostics: _UnavailablePayjoinDiagnostics(failure),
  );
}

final class _UnavailablePayjoinSender implements PayjoinSender {
  final PayjoinFailure _failure;

  const _UnavailablePayjoinSender(this._failure);

  @override
  Future<Result<PayjoinSession, PayjoinFailure>> broadcastOriginal(
    String sessionId,
  ) async => Err(_failure);

  @override
  Future<Result<bool, PayjoinFailure>> canBroadcastOriginal(
    String sessionId,
  ) async => Err(_failure);

  @override
  Future<Result<PayjoinSenderSession, PayjoinFailure>> start(
    StartPayjoinSender request,
  ) async => Err(_failure);
}

final class _UnavailablePayjoinReceiver implements PayjoinReceiver {
  final PayjoinFailure _failure;

  const _UnavailablePayjoinReceiver(this._failure);

  @override
  Future<Result<void, PayjoinFailure>> cancel(String sessionId) async =>
      Err(_failure);

  @override
  Future<Result<void, PayjoinFailure>> disableAll() async => Err(_failure);

  @override
  Future<Result<PayjoinReceiverSession, PayjoinFailure>> start(
    StartPayjoinReceiver request,
  ) async => Err(_failure);
}

final class _UnavailablePayjoinSessions implements PayjoinSessions {
  final PayjoinFailure _failure;

  const _UnavailablePayjoinSessions(this._failure);

  @override
  Future<Result<PayjoinSession?, PayjoinFailure>> byId(
    String sessionId,
  ) async => Err(_failure);

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> byTransactionId(
    String transactionId,
  ) async => Err(_failure);

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> list(
    PayjoinSessionFilter filter,
  ) async => Err(_failure);

  @override
  Future<Result<Set<Outpoint>, PayjoinFailure>> reservedOutpoints() async =>
      Err(_failure);

  @override
  Stream<Result<PayjoinSession, PayjoinFailure>> watch({
    Set<String>? sessionIds,
  }) => Stream.value(Err(_failure));
}

final class _UnavailablePayjoinPolicy implements PayjoinPolicyAccess {
  final PayjoinFailure _failure;

  const _UnavailablePayjoinPolicy(this._failure);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> load() async => Err(_failure);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setEnabled(
    bool enabled,
  ) async => Err(_failure);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setTradingEnabled(
    bool tradingEnabled,
  ) async => Err(_failure);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setSendEnabled(
    bool sendEnabled,
  ) async => Err(_failure);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setMinimumAmount(
    Sats amount,
  ) async => Err(_failure);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setSessionLifetime(
    Duration lifetime,
  ) async => Err(_failure);

  @override
  Stream<Result<PayjoinPolicy, PayjoinFailure>> watch() =>
      Stream.value(Err(_failure));
}

final class _UnavailablePayjoinDiagnostics implements PayjoinDiagnostics {
  final PayjoinFailure _failure;

  const _UnavailablePayjoinDiagnostics(this._failure);

  @override
  Future<Result<PayjoinRelayHealth, PayjoinFailure>> relayHealth() async =>
      Err(_failure);
}
