


import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger_action.freezed.dart';

@freezed
sealed class LedgerAction with _$LedgerAction {
  const factory LedgerAction.importWallet() = ImportWalletLedgerAction;
  const factory LedgerAction.signTransaction() = SignTransactionLedgerAction;
  const factory LedgerAction.verifyAddress() = VerifyAddressLedgerAction;
}
