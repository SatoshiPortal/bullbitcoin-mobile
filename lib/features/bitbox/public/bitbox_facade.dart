import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

sealed class BitBoxWalletPolicyRequest {
  final Wallet wallet;

  const BitBoxWalletPolicyRequest(this.wallet);
}

final class RegisterBitBoxWalletPolicyRequest
    extends BitBoxWalletPolicyRequest {
  const RegisterBitBoxWalletPolicyRequest(super.wallet);
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

  const VerifyBitBoxWalletPolicyAddressRequest({
    required Wallet wallet,
    required this.address,
    required this.keychain,
    required this.index,
  }) : super(wallet);
}

class BitBoxFacade {
  const BitBoxFacade();

  String get registerWalletPolicyRouteName => 'bitboxRegisterWalletPolicy';
  String get signWalletPolicyRouteName => 'bitboxSignTransaction';
  String get verifyWalletPolicyAddressRouteName => 'bitboxVerifyAddress';
}
