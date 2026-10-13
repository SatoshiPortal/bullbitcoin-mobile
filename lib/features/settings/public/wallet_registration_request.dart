import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class WalletRegistrationRequest {
  final Wallet wallet;
  final String? signerId;

  const WalletRegistrationRequest({required this.wallet, this.signerId});
}
