import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:primitives/primitives.dart';

/// Wallet snapshot + payment history + backend info read in one pass (used by
/// the cubit on load and after coin-change notifications).
class SpWalletData {
  final SpWallet wallet;
  final List<SpPayment> history;
  final List<SpCoin> coins;
  final BitcoinNetwork? network;
  final bool backendOnline;
  final int? chainTip;
  final int minBirthdayHeight;

  const SpWalletData({
    required this.wallet,
    required this.history,
    required this.coins,
    required this.network,
    required this.backendOnline,
    this.chainTip,
    this.minBirthdayHeight = 0,
  });
}
