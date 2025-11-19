


import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger_action.freezed.dart';

@freezed
sealed class LedgerAction with _$LedgerAction {
  const factory LedgerAction.importWallet() = ImportWalletLedgerAction;
  const factory LedgerAction.signTransaction() = SignTransactionLedgerAction;
  const factory LedgerAction.verifyAddress() = VerifyAddressLedgerAction;

  const LedgerAction._();

  String getTitle(BuildContext context) {
    return when(
      importWallet: () => context.loc.ledgerImportTitle,
      signTransaction: () => context.loc.ledgerSignTitle,
      verifyAddress: () => context.loc.ledgerVerifyTitle,
    );
  }

  String getButtonText(BuildContext context) {
    return when(
      importWallet: () => context.loc.ledgerImportButton,
      signTransaction: () => context.loc.ledgerSignButton,
      verifyAddress: () => context.loc.ledgerVerifyButton,
    );
  }

  String getProcessingText(BuildContext context) {
    return when(
      importWallet: () => context.loc.ledgerProcessingImport,
      signTransaction: () => context.loc.ledgerProcessingSign,
      verifyAddress: () => context.loc.ledgerProcessingVerify,
    );
  }

  String getSuccessText(BuildContext context) {
    return when(
      importWallet: () => context.loc.ledgerSuccessImportTitle,
      signTransaction: () => context.loc.ledgerSuccessSignTitle,
      verifyAddress: () => context.loc.ledgerSuccessVerifyTitle,
    );
  }

  String getProcessingSubtext(BuildContext context) {
    return when(
      importWallet: () => context.loc.ledgerProcessingImportSubtext,
      signTransaction: () => context.loc.ledgerProcessingSignSubtext,
      verifyAddress: () => context.loc.ledgerProcessingVerifySubtext,
    );
  }

  String getSuccessSubtext(BuildContext context) {
    return when(
      importWallet: () => context.loc.ledgerSuccessImportDescription,
      signTransaction: () => context.loc.ledgerSuccessSignDescription,
      verifyAddress: () => context.loc.ledgerSuccessVerifyDescription,
    );
  }
}
