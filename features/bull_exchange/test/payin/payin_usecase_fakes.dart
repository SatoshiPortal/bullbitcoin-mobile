import 'package:bull_exchange/src/payin/domain/usecases/build_payin_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/check_transaction_seen_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/send_payin_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

import '../orders/order_usecase_fakes.dart';

final class FakeBuildPayinUsecase implements BuildPayinUsecase {
  final Future<PayinBuildResult<PayinSpend>> Function(
    PayinBuild<PayinSpend> effect,
  )
  answer;

  FakeBuildPayinUsecase(this.answer);

  @override
  Future<PayinBuildResult<PayinSpend>> execute(PayinBuild<PayinSpend> effect) =>
      answer(effect);
}

final class FakeSendPayinUsecase implements SendPayinUsecase {
  final Future<PayinSendAnswered<PayinSpend>> Function(
    ExchangeSession session,
    PayinSend<PayinSpend> effect,
  )
  answer;

  FakeSendPayinUsecase(this.answer);

  @override
  Future<PayinSendAnswered<PayinSpend>> execute(
    ExchangeSession session,
    PayinSend<PayinSpend> effect,
  ) => answer(session, effect);
}

final class FakeCheckTransactionSeenUsecase
    implements CheckTransactionSeenUsecase {
  final Future<bool?> Function(String txid) answer;

  FakeCheckTransactionSeenUsecase(this.answer);

  @override
  Future<bool?> execute(String txid) => answer(txid);
}

final class FakeWatchPayjoinUsecase implements WatchPayjoinUsecase {
  final Stream<PayjoinProgress> Function(String sessionId) answer;

  FakeWatchPayjoinUsecase(this.answer);

  @override
  Stream<PayjoinProgress> execute(String sessionId) => answer(sessionId);
}

final class FakeRetryPayjoinProposalUsecase
    implements RetryPayjoinProposalUsecase {
  final Future<void> Function(String sessionId) answer;

  FakeRetryPayjoinProposalUsecase(this.answer);

  @override
  Future<void> execute(String sessionId) => answer(sessionId);
}

/// Payin use cases where every call fails the test unless given.
PayinUsecases fakePayin({
  FakeBuildPayinUsecase? build,
  FakeSendPayinUsecase? send,
  FakeGetOrderUsecase? getOrder,
  FakeCheckTransactionSeenUsecase? transactionSeen,
  FakeWatchPayjoinUsecase? watchPayjoin,
  FakeRetryPayjoinProposalUsecase? retryPayjoin,
}) => PayinUsecases(
  build:
      build ?? FakeBuildPayinUsecase((_) => throw StateError('no payin build')),
  send:
      send ?? FakeSendPayinUsecase((_, _) => throw StateError('no payin send')),
  getOrder:
      getOrder ??
      FakeGetOrderUsecase((_, _) => throw StateError('no order read')),
  transactionSeen:
      transactionSeen ??
      FakeCheckTransactionSeenUsecase(
        (_) => throw StateError('no transaction look-up'),
      ),
  watchPayjoin:
      watchPayjoin ??
      FakeWatchPayjoinUsecase((_) => throw StateError('no payjoin watch')),
  retryPayjoin:
      retryPayjoin ??
      FakeRetryPayjoinProposalUsecase(
        (_) => throw StateError('no payjoin retry'),
      ),
);
