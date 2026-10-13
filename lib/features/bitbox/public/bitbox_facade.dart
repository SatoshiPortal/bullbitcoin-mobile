import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';

final class ReadBitBoxAccountKeyRequest {
  final SignerDeviceEntity deviceType;
  final String derivationPath;
  final bool isTestnet;

  const ReadBitBoxAccountKeyRequest({
    required this.deviceType,
    required this.derivationPath,
    required this.isTestnet,
  });
}

sealed class BitBoxWalletPolicyRequest {
  final Wallet wallet;

  const BitBoxWalletPolicyRequest(this.wallet);
}

final class RegisterBitBoxWalletPolicyRequest
    extends BitBoxWalletPolicyRequest {
  final String? signerId;

  const RegisterBitBoxWalletPolicyRequest(super.wallet, {this.signerId});
}

final class SignBitBoxWalletPolicyRequest extends BitBoxWalletPolicyRequest {
  final String signerId;
  final String psbt;

  const SignBitBoxWalletPolicyRequest({
    required Wallet wallet,
    required this.signerId,
    required this.psbt,
  }) : super(wallet);
}

final class VerifyBitBoxWalletPolicyAddressRequest
    extends BitBoxWalletPolicyRequest {
  final String address;
  final BitcoinPolicyKeychain keychain;
  final int index;
  final String? signerId;

  const VerifyBitBoxWalletPolicyAddressRequest({
    required Wallet wallet,
    required this.address,
    required this.keychain,
    required this.index,
    this.signerId,
  }) : super(wallet);
}

class BitBoxFacade {
  const BitBoxFacade();

  String get readAccountKeyRouteName => 'importBitBox';
  String get registerWalletPolicyRouteName => 'bitboxRegisterWalletPolicy';
  String get signWalletPolicyRouteName => 'bitboxSignTransaction';
  String get verifyWalletPolicyAddressRouteName => 'bitboxVerifyAddress';
}
