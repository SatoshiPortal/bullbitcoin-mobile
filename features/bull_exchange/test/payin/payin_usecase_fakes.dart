import 'package:bull_exchange/src/payin/domain/usecases/build_payin_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/check_transaction_seen_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/get_fee_options_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/get_wallet_coins_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/preview_custom_fee_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/preview_fee_presets_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/send_payin_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:bull_exchange/src/payin/spend_options_runner.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fees/fees.dart';
import 'package:sync/sync.dart' show Coin;

import '../orders/order_usecase_fakes.dart';

final class FakeBuildPayinUsecase implements BuildPayinUsecase {
  final Future<Result<PayinBuilt<PayinSpend>, ExchangePayinBuildFailure>>
  Function(PayinBuild<PayinSpend> effect)
  answer;

  FakeBuildPayinUsecase(this.answer);

  @override
  Future<Result<PayinBuilt<PayinSpend>, ExchangePayinBuildFailure>> execute(
    PayinBuild<PayinSpend> effect,
  ) => answer(effect);
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

final class FakeGetFeeOptionsUsecase implements GetFeeOptionsUsecase {
  final Future<FeeOptions?> Function(ExchangeSession session) answer;

  FakeGetFeeOptionsUsecase(this.answer);

  @override
  Future<FeeOptions?> execute(ExchangeSession session) => answer(session);
}

final class FakeGetWalletCoinsUsecase implements GetWalletCoinsUsecase {
  final Future<List<Coin>?> Function(String walletId) answer;

  FakeGetWalletCoinsUsecase(this.answer);

  @override
  Future<List<Coin>?> execute(String walletId) => answer(walletId);
}

final class FakePreviewFeePresetsUsecase implements PreviewFeePresetsUsecase {
  final Future<Map<FeeSelection, BitcoinFeePreviewSlot>> Function(
    SpendPreviewShape shape,
    FeeOptions fees,
  )
  answer;

  FakePreviewFeePresetsUsecase(this.answer);

  @override
  Future<Map<FeeSelection, BitcoinFeePreviewSlot>> execute(
    SpendPreviewShape shape,
    FeeOptions fees,
  ) => answer(shape, fees);
}

final class FakePreviewCustomFeeUsecase implements PreviewCustomFeeUsecase {
  final Future<BitcoinFeePreviewSlot> Function(
    SpendPreviewShape shape,
    NetworkFee fee,
  )
  answer;

  FakePreviewCustomFeeUsecase(this.answer);

  @override
  Future<BitcoinFeePreviewSlot> execute(
    SpendPreviewShape shape,
    NetworkFee fee,
  ) => answer(shape, fee);
}

/// Spend options use cases where every call fails the test unless given.
SpendOptionsUsecases fakeSpendOptions({
  FakeGetFeeOptionsUsecase? getFees,
  FakeGetWalletCoinsUsecase? getCoins,
  FakePreviewFeePresetsUsecase? previewPresets,
  FakePreviewCustomFeeUsecase? previewCustom,
}) => SpendOptionsUsecases(
  getFees:
      getFees ??
      FakeGetFeeOptionsUsecase((_) => throw StateError('no fee estimates')),
  getCoins:
      getCoins ??
      FakeGetWalletCoinsUsecase((_) => throw StateError('no coin read')),
  previewPresets:
      previewPresets ??
      FakePreviewFeePresetsUsecase(
        (_, _) => throw StateError('no preset preview'),
      ),
  previewCustom:
      previewCustom ??
      FakePreviewCustomFeeUsecase(
        (_, _) => throw StateError('no custom preview'),
      ),
);
