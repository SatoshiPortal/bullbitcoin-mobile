
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

  String get title {
    return when(
      unlockDevice: () => 'Unlock BitBox Device',
      pairDevice: () => 'Pair BitBox Device',
      importWallet: () => 'Import BitBox Wallet',
      signTransaction: () => 'Sign Transaction',
      verifyAddress: () => 'Verify Address on BitBox',
    );
  }

  String get buttonText {
    return when(
      unlockDevice: () => 'Unlock Device',
      pairDevice: () => 'Start Pairing',
      importWallet: () => 'Start Import',
      signTransaction: () => 'Start Signing',
      verifyAddress: () => 'Verify Address',
    );
  }

  String get processingText {
    return when(
      unlockDevice: () => 'Unlocking Device',
      pairDevice: () => 'Pairing Device',
      importWallet: () => 'Importing Wallet',
      signTransaction: () => 'Signing Transaction',
      verifyAddress: () => 'Showing address on BitBox...',
    );
  }

  String get successText {
    return when(
      unlockDevice: () => 'Device Unlocked Successfully',
      pairDevice: () => 'Device Paired Successfully',
      importWallet: () => 'Wallet Imported Successfully',
      signTransaction: () => 'Transaction Signed Successfully',
      verifyAddress: () => 'Address Verified Successfully',
    );
  }

  String get successSubText {
    return when(
      unlockDevice: () => 'Your BitBox device is now unlocked and ready to use.',
      pairDevice: () => 'Your BitBox device is now paired and ready to use.',
      importWallet: () => 'Your BitBox wallet has been imported successfully.',
      signTransaction: () => 'Your transaction has been signed successfully.',
      verifyAddress: () => 'The address has been verified on your BitBox device.',
    );
  }

  String get processingSubText {
    return when(
      unlockDevice: () => 'Please enter your password on the BitBox device...',
      pairDevice: () => 'Please verify the pairing code on your BitBox device...',
      importWallet: () => 'Setting up your watch-only wallet...',
      signTransaction: () => 'Please confirm the transaction on your BitBox device...',
      verifyAddress: () => 'Please confirm the address on your BitBox device.',
    );
  }
}
