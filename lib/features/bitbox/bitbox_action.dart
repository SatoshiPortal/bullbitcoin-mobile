import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bitbox_action.freezed.dart';

@freezed
sealed class BitBoxAction with _$BitBoxAction {
  const factory BitBoxAction.unlockDevice() = UnlockDeviceBitBoxAction;
  const factory BitBoxAction.pairDevice() = PairDeviceBitBoxAction;
  const factory BitBoxAction.importWallet() = ImportWalletBitBoxAction;
  const factory BitBoxAction.signTransaction() = SignTransactionBitBoxAction;
  const factory BitBoxAction.verifyAddress() = VerifyAddressBitBoxAction;

  const BitBoxAction._();

  String toTitle(BuildContext context) {
    return when(
      unlockDevice: () => context.loc.bitboxActionUnlockDeviceTitle,
      pairDevice: () => context.loc.bitboxActionPairDeviceTitle,
      importWallet: () => context.loc.bitboxActionImportWalletTitle,
      signTransaction: () => context.loc.bitboxActionSignTransactionTitle,
      verifyAddress: () => context.loc.bitboxActionVerifyAddressTitle,
    );
  }

  String toButtonText(BuildContext context) {
    return when(
      unlockDevice: () => context.loc.bitboxActionUnlockDeviceButton,
      pairDevice: () => context.loc.bitboxActionPairDeviceButton,
      importWallet: () => context.loc.bitboxActionImportWalletButton,
      signTransaction: () => context.loc.bitboxActionSignTransactionButton,
      verifyAddress: () => context.loc.bitboxActionVerifyAddressButton,
    );
  }

  String toProcessingText(BuildContext context) {
    return when(
      unlockDevice: () => context.loc.bitboxActionUnlockDeviceProcessing,
      pairDevice: () => context.loc.bitboxActionPairDeviceProcessing,
      importWallet: () => context.loc.bitboxActionImportWalletProcessing,
      signTransaction: () => context.loc.bitboxActionSignTransactionProcessing,
      verifyAddress: () => context.loc.bitboxActionVerifyAddressProcessing,
    );
  }

  String toSuccessText(BuildContext context) {
    return when(
      unlockDevice: () => context.loc.bitboxActionUnlockDeviceSuccess,
      pairDevice: () => context.loc.bitboxActionPairDeviceSuccess,
      importWallet: () => context.loc.bitboxActionImportWalletSuccess,
      signTransaction: () => context.loc.bitboxActionSignTransactionSuccess,
      verifyAddress: () => context.loc.bitboxActionVerifyAddressSuccess,
    );
  }

  String toSuccessSubText(BuildContext context) {
    return when(
      unlockDevice: () => context.loc.bitboxActionUnlockDeviceSuccessSubtext,
      pairDevice: () => context.loc.bitboxActionPairDeviceSuccessSubtext,
      importWallet: () => context.loc.bitboxActionImportWalletSuccessSubtext,
      signTransaction: () => context.loc.bitboxActionSignTransactionSuccessSubtext,
      verifyAddress: () => context.loc.bitboxActionVerifyAddressSuccessSubtext,
    );
  }

  String toProcessingSubText(BuildContext context) {
    return when(
      unlockDevice: () => context.loc.bitboxActionUnlockDeviceProcessingSubtext,
      pairDevice: () => context.loc.bitboxActionPairDeviceProcessingSubtext,
      importWallet: () => context.loc.bitboxActionImportWalletProcessingSubtext,
      signTransaction: () =>
          context.loc.bitboxActionSignTransactionProcessingSubtext,
      verifyAddress: () => context.loc.bitboxActionVerifyAddressProcessingSubtext,
    );
  }
}
