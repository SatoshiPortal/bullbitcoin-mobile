import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
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
    // address
    @Default(SendStep.address) SendStep step,
    @Default(SendType.lightning) SendType sendType,
    @Default('') String addressOrInvoice,
    // amount
    Wallet? wallet,
    @Default('') String amount,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String fiatCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String label,
    // confirm
    @Default([]) List<Utxo> utxos,
    @Default([]) List<Utxo> selectedUtxos,
    @Default(false) bool replaceByFee,
    @Default([]) List<int> feesList,
    @Default(0) int feeRate,
    //
    WalletTransaction? transaction,
    LnSendSwap? swap,
    Object? error,
  }) = _SendState;
  const SendState._();
}
