import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/ark/ark.dart';

class ArkWallet {
  final ark_wallet.ArkWallet wallet;

  ArkWallet({required this.wallet});

  static Future<ArkWallet> init({required List<int> secretKey}) async {
    final wallet = await ark_wallet.ArkWallet.init(
      secretKey: secretKey,
      network: Ark.network,
      esplora: Ark.esplora,
      server: Ark.server,
    );
    return ArkWallet(wallet: wallet);
  }

  String get offchainAddress => wallet.offchainAddress();
  String get boardingAddress => wallet.boardingAddress();

  Future<({int confirmed, int pending, int total})> get balance async {
    final balance = await wallet.balance();
    return (
      confirmed: balance.confirmed,
      pending: balance.pending,
      total: balance.total,
    );
  }

  Future<List<ark_wallet.Transaction>> get transactions async {
    return await wallet.transactionHistory();
  }
}
