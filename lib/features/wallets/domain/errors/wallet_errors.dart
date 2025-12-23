import 'package:bb_mobile/core/primitives/network/network.dart';
import 'package:bb_mobile/core/primitives/signer/signer.dart';
import 'package:bb_mobile/core/primitives/signer/signer_device.dart';

class WrongDefaultWalletNetworkError implements Exception {
  final Network network;

  const WrongDefaultWalletNetworkError({required this.network});

  @override
  String toString() =>
      'WrongDefaultWalletNetworkError: Only Bitcoin Mainnet and Liquid Mainnet wallets can be default wallets. Given network: $network';
}

class MissingSignerDeviceError implements Exception {
  final int walletId;

  const MissingSignerDeviceError({required this.walletId});

  @override
  String toString() =>
      'MissingSignerDeviceError: Wallet with ID $walletId requires a signer device but none was provided.';
}

class WrongSignerForDeviceError implements Exception {
  final int walletId;
  final Signer signer;
  final SignerDevice signerDevice;

  const WrongSignerForDeviceError({
    required this.walletId,
    required this.signer,
    required this.signerDevice,
  });

  @override
  String toString() =>
      'WrongSignerForDeviceError: Wallet with ID $walletId has signer $signer which is incompatible with signer device $signerDevice.';
}

class InvalidBalanceError implements Exception {
  final String field;
  final int value;

  const InvalidBalanceError({required this.field, required this.value});

  @override
  String toString() =>
      'InvalidBalanceError: $field cannot be negative. Given value: $value';
}

class InvalidOutputError implements Exception {
  final String field;
  final dynamic value;

  const InvalidOutputError({required this.field, required this.value});

  @override
  String toString() =>
      'InvalidOutputError: Invalid $field. Given value: $value';
}
