import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/ark/ark.dart';
import 'package:bb_mobile/core/ark/entities/ark_balance.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:convert/convert.dart' as convert;
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class ArkWalletEntity {
  final ark_wallet.ArkWallet wallet;
  final List<int> _secretKey;

  ArkWalletEntity({required this.wallet, required List<int> secretKey})
    : _secretKey = secretKey;

  static Future<ArkWalletEntity> init({required List<int> secretKey}) async {
    try {
      final wallet = await ark_wallet.ArkWallet.init(
        secretKey: secretKey,
        network: Ark.network,
        esplora: Ark.esplora,
        server: Ark.server,
        boltz: Ark.boltz,
      );
      return ArkWalletEntity(wallet: wallet, secretKey: secretKey);
    } catch (e) {
      throw ArkError(e.toString());
    }
  }

  String get offchainAddress => wallet.offchainAddress();
  String get boardingAddress => wallet.boardingAddress();
  String get secretHex => convert.hex.encode(_secretKey);
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

      return arkBalance;
    } catch (e) {
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
