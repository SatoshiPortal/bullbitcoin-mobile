import 'package:bb_mobile/features/wallet/domain/wallet.dart';

class WalletRegistrationRequest {
  final Wallet wallet;
  final String? signerId;

  const WalletRegistrationRequest({required this.wallet, this.signerId});
}
