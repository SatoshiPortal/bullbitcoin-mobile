import 'dart:io';

import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

import '../../../domain/ports/wallet_connection_port.dart';
import '../../../domain/public_wallet_descriptor.dart';
import 'native_store_errors.dart';

/// The LWK wallet store. LWK manages its own directories beneath the
/// published root, and its sync is one indivisible SDK call.
final class LwkWalletStoreDatasource {
  final lwk.Wallet wallet;

  LwkWalletStoreDatasource._(this.wallet);

  static lwk.LiquidNetwork? network(Network network) => switch (network) {
    LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
    LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
    LiquidNetwork.regtest => lwk.LiquidNetwork.regtest,
    _ => null,
  };

  /// Initializing may mutate LWK's cache: callers hold the writer lock.
  static Future<LwkWalletStoreDatasource> open(
    String path,
    LiquidWalletDescriptor descriptor,
  ) async {
    final expected = network(descriptor.key.network);
    if (expected == null) throw const NativeNetworkUnsupported();
    return LwkWalletStoreDatasource._(
      await lwk.Wallet.init(
        network: expected,
        dbpath: path,
        descriptor: lwk.Descriptor(
          ctDescriptor: descriptor.combinedCtDescriptor,
        ),
      ),
    );
  }

  /// ⚠️ Connects directly, never through Tor: the pinned LWK has no SOCKS
  /// option, so [WalletConnection.socks5] cannot be honored here. The
  /// connection policy drops the proxy for Liquid before reaching this call.
  Future<void> sync(WalletConnection connection, {int? stopAtIndex}) =>
      wallet.sync_(
        electrumUrl: connection.url,
        validateDomain: connection.validateDomain,
        timeout: connection.timeout.inSeconds,
        stopAtIndex: stopAtIndex,
      );

  Future<Set<String>> incomingTxids() async => {
    for (final tx in await wallet.txs())
      if (tx.kind == 'incoming') tx.txid,
  };

  static void delete(String path) {
    final directory = Directory(path);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }

  void close() => wallet.dispose();
}
