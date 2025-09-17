import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/ark/ark.dart';

class ArkWalletEntity {
  final ark_wallet.ArkWallet wallet;

  ArkWalletEntity({required this.wallet});

  static Future<ArkWalletEntity> init({required List<int> secretKey}) async {
    final wallet = await ark_wallet.ArkWallet.init(
      secretKey: secretKey,
      network: Ark.network,
      esplora: Ark.esplora,
      server: Ark.server,
    );
    return ArkWalletEntity(wallet: wallet);
  }

  String get offchainAddress => wallet.offchainAddress();
  String get boardingAddress => wallet.boardingAddress();
  static bool isArkAddress(String address) =>
      ark_wallet.Utils.isArk(address: address);
  static bool isBtcAddress(String address) =>
      ark_wallet.Utils.isBtc(address: address);

  Future<({int confirmed, int pending, int total})> get balance async {
    final balance = await wallet.balance();
    return (
      confirmed: balance.confirmed,
      pending: balance.pending,
      total: balance.total,
    );
  }

  Future<List<ark_wallet.Transaction>> get transactions =>
      wallet.transactionHistory();

  Future<void> settle(bool selectRecoverableVtxos) =>
      wallet.settle(selectRecoverableVtxos: selectRecoverableVtxos);

  Future<void> sendOffchain({required int amount, required String address}) =>
      wallet.sendOffChain(sats: amount, address: address);

  Future<void> sendOnChain({required int amount, required String address}) =>
      wallet.sendOnChain(sats: amount, address: address);
}
