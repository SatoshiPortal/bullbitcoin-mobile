import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

final class ReadLedgerAccountKeyRequest {
  final SignerDeviceEntity deviceType;
  final String derivationPath;

  const ReadLedgerAccountKeyRequest({
    required this.deviceType,
    required this.derivationPath,
  });
}

sealed class LedgerWalletPolicyRequest {
  final Wallet wallet;
  final SignerDeviceEntity? requestedDeviceType;

  const LedgerWalletPolicyRequest(this.wallet, {this.requestedDeviceType});
}

final class RegisterLedgerWalletPolicyRequest
    extends LedgerWalletPolicyRequest {
  final String? signerId;

  const RegisterLedgerWalletPolicyRequest(
    super.wallet, {
    super.requestedDeviceType,
    this.signerId,
  });
}

final class SignLedgerWalletPolicyRequest extends LedgerWalletPolicyRequest {
  final String signerId;
  final String psbt;

  const SignLedgerWalletPolicyRequest({
    required Wallet wallet,
    required this.signerId,
    required this.psbt,
    required SignerDeviceEntity requestedDeviceType,
  }) : super(wallet, requestedDeviceType: requestedDeviceType);
}

final class VerifyLedgerWalletPolicyAddressRequest
    extends LedgerWalletPolicyRequest {
  final String address;
  final BitcoinPolicyKeychain keychain;
  final int index;
  final String? signerId;

  const VerifyLedgerWalletPolicyAddressRequest({
    required Wallet wallet,
    required this.address,
    required this.keychain,
    required this.index,
    this.signerId,
    SignerDeviceEntity? requestedDeviceType,
  }) : super(wallet, requestedDeviceType: requestedDeviceType);
}

class LedgerFacade {
  const LedgerFacade();

  String get readAccountKeyRouteName => 'importLedger';
  String get registerWalletPolicyRouteName => 'ledgerRegisterWalletPolicy';
  String get signWalletPolicyRouteName => 'ledgerSignTransaction';
  String get verifyWalletPolicyAddressRouteName => 'ledgerVerifyAddress';
}
