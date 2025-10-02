


import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger_action.freezed.dart';

@freezed
sealed class LedgerAction with _$LedgerAction {
  const factory LedgerAction.importWallet() = ImportWalletLedgerAction;
  const factory LedgerAction.signTransaction() = SignTransactionLedgerAction;
  const factory LedgerAction.verifyAddress() = VerifyAddressLedgerAction;

  const LedgerAction._();

  String get title {
    return when(
      importWallet: () => 'Import Ledger Wallet',
      signTransaction: () => 'Sign Transaction',
      verifyAddress: () => 'Verify Address on Ledger',
    );
  }

  String get buttonText {
    return when(
      importWallet: () => 'Start Import',
      signTransaction: () => 'Start Signing',
      verifyAddress: () => 'Verify Address',
    );
  }

  String get processingText {
    return when(
      importWallet: () => 'Importing Wallet',
      signTransaction: () => 'Signing Transaction',
      verifyAddress: () => 'Showing address on Ledger...',
    );
  }

  String get successText {
    return when(
      importWallet: () => 'Wallet Imported Successfully',
      signTransaction: () => 'Transaction Signed Successfully',
      verifyAddress: () => 'Verifying address on Ledger...',
    );
  }

  String get successSubText {
    return when(
      importWallet: () => 'Your Ledger wallet has been imported successfully.',
      signTransaction: () => 'Your transaction has been signed successfully.',
      verifyAddress:
          () => 'The address has been verified on your Ledger device.',
    );
  }

  String get processingSubText {
    return when(
      importWallet: () => 'Setting up your watch-only wallet...',
      signTransaction:
          () => 'Please confirm the transaction on your Ledger device...',
      verifyAddress: () => 'Please confirm the address on your Ledger device.',
    );
  }
}
