import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'send_state.freezed.dart';

enum SendType {
  bitcoin,
  lightning,
  liquid,
}

enum SendStep {
  address,
  amount,
  confirm,
  sending,
  sent,
}

@freezed
class SendState with _$SendState {
  const factory SendState({
    @Default(SendStep.address) SendStep step,
    @Default(SendType.lightning) SendType sendType,
    // input
    @Default('') String addressOrInvoice,
    Wallet? wallet,
    @Default('') String amount,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String fiatCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String label,
    @Default([]) List<Utxo> utxos,
    @Default([]) List<Utxo> selectedUtxos,
    @Default(false) bool replaceByFee,
    @Default([]) List<int> feesList,
    @Default(0) int feeRate,
    // prepare
    String? bitcoinPsbt,
    String? liquidTransaction,
    LnSendSwap? lightningSwap,
    // confirm
    String? txId,
    Object? error,
  }) = _SendState;
  const SendState._();
}
