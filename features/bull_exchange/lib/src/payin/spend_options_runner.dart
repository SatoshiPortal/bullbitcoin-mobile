import 'dart:async';

import 'package:bull_exchange/src/payin/domain/usecases/get_fee_options_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/get_wallet_coins_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/preview_custom_fee_usecase.dart';
import 'package:bull_exchange/src/payin/domain/usecases/preview_fee_presets_usecase.dart';
import 'package:bull_exchange/src/payin/payin_spend_calls.dart';
import 'package:bull_exchange/src/payin/spend_options_event.dart';
import 'package:bull_exchange/src/payin/spend_options_effect.dart';
import 'package:exchange/exchange.dart';

/// The use cases of the spend options (sell and pay): the fee estimates,
/// the coins of a wallet and unsigned previews of the payin (never sent).
/// Each answers null / an empty slot when the wallet can't tell. Only
/// [SpendOptionsRunner] calls them; a flow's bloc hands them over.
final class SpendOptionsUsecases {
  final GetFeeOptionsUsecase getFees;
  final GetWalletCoinsUsecase getCoins;
  final PreviewFeePresetsUsecase previewPresets;
  final PreviewCustomFeeUsecase previewCustom;

  const SpendOptionsUsecases({
    required this.getFees,
    required this.getCoins,
    required this.previewPresets,
    required this.previewCustom,
  });

  SpendOptionsUsecases.of(PayinWalletServices wallets)
    : this(
        getFees: GetFeeOptionsUsecase(wallets.fees),
        getCoins: GetWalletCoinsUsecase(wallets.coins),
        previewPresets: PreviewFeePresetsUsecase(wallets.spend),
        previewCustom: PreviewCustomFeeUsecase(wallets.spend),
      );
}

/// Runs the spend options' effects with the flow's session; every answer
/// carries the attempt or epoch of its effect.
final class SpendOptionsRunner {
  final SpendOptionsUsecases _usecases;
  final ExchangeSession _session;
  final void Function(SpendOptionsEvent event) _emit;
  bool _closed = false;

  SpendOptionsRunner(this._usecases, this._session, this._emit);

  void run(List<SpendOptionsEffect> effects) {
    for (final effect in effects) {
      switch (effect) {
        case SpendLoadFees(:final attempt):
          _answer(
            _usecases.getFees
                .execute(_session)
                .then(
                  (fees) => fees == null
                      ? SpendFeesFailed(attempt)
                      : SpendFeesLoaded(attempt, fees),
                ),
          );
        case SpendLoadCoins(:final walletId):
          _answer(
            _usecases.getCoins.execute(walletId).then(SpendCoinsRead.new),
          );
        case SpendPreviewPresets(:final epoch, :final fees, :final shape):
          _answer(
            _usecases.previewPresets
                .execute(shape, fees)
                .then((slots) => SpendPresetsPreviewed(epoch, slots)),
          );
        case SpendPreviewCustom(:final epoch, :final fee, :final shape):
          _answer(
            _usecases.previewCustom
                .execute(shape, fee)
                .then((slot) => SpendCustomPreviewed(epoch, fee, slot)),
          );
      }
    }
  }

  void _answer(Future<SpendOptionsEvent> answer) => unawaited(
    answer.then((event) {
      if (!_closed) _emit(event);
    }),
  );

  void close() => _closed = true;
}
