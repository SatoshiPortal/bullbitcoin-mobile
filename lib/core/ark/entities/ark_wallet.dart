import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/ark/ark.dart';
import 'package:bb_mobile/core/ark/entities/ark_balance.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class ArkWalletEntity {
  final ark_wallet.ArkWallet wallet;

  ArkWalletEntity({required this.wallet});

  static Future<ArkWalletEntity> init({required List<int> secretKey}) async {
    try {
      final wallet = await ark_wallet.ArkWallet.init(
        secretKey: secretKey,
        network: Ark.network,
        esplora: Ark.esplora,
        server: Ark.server,
        boltz: Ark.boltz,
      );
      return ArkWalletEntity(wallet: wallet);
    } catch (e) {
      log.severe('[ArkWalletEntity] Failed to initialize ark wallet: $e');
      throw ArkError(e.toString());
    }
  }

  String get offchainAddress => wallet.offchainAddress();
  String get boardingAddress => wallet.boardingAddress();
  static bool isArkAddress(String address) {
    try {
      return ark_wallet.Utils.isArk(address: address);
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isBtcAddress(String address) async {
    try {
      final satoshified = await satoshifier.Satoshifier.parse(address);
      return satoshified is satoshifier.BitcoinAddress;
    } catch (e) {
      return false;
    }
  }

  Future<ArkBalance> get balance async {
    try {
      log.info('[ArkWalletEntity] Fetching ARK wallet balance');
      final balance = await wallet.balance();

      final arkBalance = ArkBalance(
        preconfirmed: balance.preconfirmed,
        settled: balance.settled,
        available: balance.available,
        recoverable: balance.recoverable,
        total: balance.total,
        boarding: ArkBoarding(
          unconfirmed: balance.boarding.unconfirmed,
          confirmed: balance.boarding.confirmed,
          total: balance.boarding.total,
        ),
      );

      log.info(
        '[ArkWalletEntity] ARK balance fetched - boarding unconfirmed: ${arkBalance.boarding.unconfirmed}, boarding confirmed: ${arkBalance.boarding.confirmed}, total: ${arkBalance.total}',
      );
      return arkBalance;
    } catch (e) {
      log.severe('[ArkWalletEntity] Failed to fetch ARK balance: $e');
      rethrow;
    }
  }

  Future<List<ark_wallet.Transaction>> get transactions =>
      wallet.transactionHistory();

  Future<void> settle(bool selectRecoverableVtxos) =>
      wallet.settle(selectRecoverableVtxos: selectRecoverableVtxos);

  Future<String> sendOffchain({required int amount, required String address}) =>
      wallet.sendOffChain(sats: amount, address: address);

  Future<String> sendOnChain({required int amount, required String address}) =>
      wallet.sendOnChain(sats: amount, address: address);

  Future<String> collaborativeRedeem({
    required int amount,
    required String address,
    required bool selectRecoverableVtxos,
  }) => wallet.collaborativeRedeem(
    sats: amount,
    address: address,
    selectRecoverableVtxos: selectRecoverableVtxos,
  );

  ark_wallet.ServerInfo get serverInfo => wallet.serverInfo();
}
