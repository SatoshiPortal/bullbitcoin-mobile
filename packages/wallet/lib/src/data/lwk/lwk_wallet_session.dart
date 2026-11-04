import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:transaction_sync/transaction_sync.dart';

/// Owns a native Liquid wallet for one coordinated operation.
final class LwkWalletSession {
  final lwk.Wallet wallet;

  LwkWalletSession._(this.wallet);

  static Future<LwkWalletSession> open(
    LwkElectrumConfiguration configuration,
  ) async => LwkWalletSession._(
    await openNativeWallet(
      network: configuration.isTestnet
          ? lwk.LiquidNetwork.testnet
          : lwk.LiquidNetwork.mainnet,
      databasePath: configuration.databaseRootPath,
      descriptor: lwk.Descriptor(
        ctDescriptor: configuration.confidentialPublicDescriptor,
      ),
    ),
  );

  static Future<lwk.Wallet> openNativeWallet({
    required lwk.LiquidNetwork network,
    required String databasePath,
    required lwk.Descriptor descriptor,
  }) => lwk.Wallet.init(
    network: network,
    dbpath: databasePath,
    descriptor: descriptor,
  );

  void dispose() => wallet.dispose();
}
