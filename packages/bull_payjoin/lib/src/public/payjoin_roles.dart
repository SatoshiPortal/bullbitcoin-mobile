import 'package:bull_payjoin/src/domain/payjoin_failure.dart';
import 'package:bull_payjoin/src/domain/payjoin_policy.dart';
import 'package:bull_payjoin/src/domain/payjoin_requests.dart';
import 'package:bull_payjoin/src/domain/payjoin_session.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

abstract interface class PayjoinSender {
  @useResult
  Future<Result<PayjoinSenderSession, PayjoinFailure>> start(
    StartPayjoinSender request,
  );

  @useResult
  Future<Result<PayjoinSession, PayjoinFailure>> broadcastOriginal(
    String sessionId,
  );

  @useResult
  Future<Result<bool, PayjoinFailure>> canBroadcastOriginal(String sessionId);
}

abstract interface class PayjoinReceiver {
  @useResult
  Future<Result<PayjoinReceiverSession, PayjoinFailure>> start(
    StartPayjoinReceiver request,
  );

  @useResult
  Future<Result<void, PayjoinFailure>> cancel(String sessionId);

  @useResult
  Future<Result<void, PayjoinFailure>> disableAll();
}

abstract interface class PayjoinSessions {
  @useResult
  Future<Result<PayjoinSession?, PayjoinFailure>> byId(String sessionId);

  @useResult
  Future<Result<List<PayjoinSession>, PayjoinFailure>> byTransactionId(
    String transactionId,
  );

  @useResult
  Future<Result<List<PayjoinSession>, PayjoinFailure>> list(
    PayjoinSessionFilter filter,
  );

  Stream<Result<PayjoinSession, PayjoinFailure>> watch({
    Set<String>? sessionIds,
  });

  @useResult
  Future<Result<Set<Outpoint>, PayjoinFailure>> reservedOutpoints();
}

abstract interface class PayjoinPolicyAccess {
  @useResult
  Future<Result<PayjoinPolicy, PayjoinFailure>> load();

  Stream<Result<PayjoinPolicy, PayjoinFailure>> watch();

  @useResult
  Future<Result<PayjoinPolicy, PayjoinFailure>> setEnabled(bool enabled);

  @useResult
  Future<Result<PayjoinPolicy, PayjoinFailure>> setTradingEnabled(
    bool tradingEnabled,
  );

  @useResult
  Future<Result<PayjoinPolicy, PayjoinFailure>> setSendEnabled(
    bool sendEnabled,
  );

  @useResult
  Future<Result<PayjoinPolicy, PayjoinFailure>> setMinimumAmount(Sats amount);

  @useResult
  Future<Result<PayjoinPolicy, PayjoinFailure>> setSessionLifetime(
    Duration lifetime,
  );
}

abstract interface class PayjoinDiagnostics {
  @useResult
  Future<Result<PayjoinRelayHealth, PayjoinFailure>> relayHealth();
}
