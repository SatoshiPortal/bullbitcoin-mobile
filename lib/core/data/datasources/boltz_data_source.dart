import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:boltz/boltz.dart';

enum BroadcastProvider { local, boltz }

abstract class BoltzDataSource {
  Future<ReverseFeesAndLimits> getReverseFeesAndLimits();
  Future<BtcLnSwap> createBtcReverseSwap(
    String mnemonic,
    BigInt index,
    BigInt outAmount,
    Environment environment,
    String electrumUrl,
  );

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> claimBtcReverseSwap(
    BtcLnSwap btcLnSwap,
    String claimAddress,
    int absoluteFees,
    bool tryCooperate,
  );
  Future<String> broadcastBtcLnSwap(
    BtcLnSwap btcLnSwap,
    String signedTxHex,
    BroadcastProvider provider,
  );
  Future<LbtcLnSwap> createLBtcReverseSwap(
    String mnemonic,
    BigInt index,
    BigInt outAmount,
    Environment environment,
    String electrumUrl,
  );

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> claimLBtcReverseSwap(
    LbtcLnSwap lbtcLnSwap,
    String claimAddress,
    int absoluteFees,
    bool tryCooperate,
  );

  Future<String> broadcastLbtcLnSwap(
    LbtcLnSwap lbtcLnSwap,
    String signedTxHex,
    BroadcastProvider provider,
  );
}

class BoltzDataSourceImpl implements BoltzDataSource {
  final String _url;

  BoltzDataSourceImpl({String url = 'api.boltz.exchange/v2'}) : _url = url;

  // REVERSE SWAPS

  @override
  Future<ReverseFeesAndLimits> getReverseFeesAndLimits() async {
    final fees = Fees(boltzUrl: _url);
    final reverse = await fees.reverse();
    return reverse;
  }

  @override
  Future<BtcLnSwap> createBtcReverseSwap(
    String mnemonic,
    BigInt index,
    BigInt outAmount,
    Environment environment,
    String electrumUrl,
  ) async {
    return BtcLnSwap.newReverse(
      mnemonic: mnemonic,
      index: index,
      outAmount: outAmount,
      network: environment.toBtcChain(),
      electrumUrl: electrumUrl,
      boltzUrl: _url,
    );
  }

  @override
  Future<String> claimBtcReverseSwap(
    BtcLnSwap btcLnSwap,
    String claimAddress,
    int absoluteFees,
    bool tryCooperate,
  ) async {
    return btcLnSwap.claim(
      outAddress: claimAddress,
      absFee: BigInt.from(absoluteFees),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<LbtcLnSwap> createLBtcReverseSwap(
    String mnemonic,
    BigInt index,
    BigInt outAmount,
    Environment environment,
    String electrumUrl,
  ) async {
    return LbtcLnSwap.newReverse(
      mnemonic: mnemonic,
      index: index,
      outAmount: outAmount,
      network: environment.toLbtcChain(),
      electrumUrl: electrumUrl,
      boltzUrl: _url,
    );
  }

  @override
  Future<String> claimLBtcReverseSwap(
    LbtcLnSwap lbtcLnSwap,
    String claimAddress,
    int absoluteFees,
    bool tryCooperate,
  ) async {
    return lbtcLnSwap.claim(
      outAddress: '',
      absFee: BigInt.from(absoluteFees),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<String> broadcastBtcLnSwap(
    BtcLnSwap btcLnSwap,
    String signedTxHex,
    BroadcastProvider provider,
  ) {
    switch (provider) {
      case BroadcastProvider.local:
        return btcLnSwap.broadcastLocal(
          signedHex: signedTxHex,
        );
      case BroadcastProvider.boltz:
        return btcLnSwap.broadcastBoltz(
          signedHex: signedTxHex,
        );
    }
  }

  @override
  Future<String> broadcastLbtcLnSwap(
    LbtcLnSwap lbtcLnSwap,
    String signedTxHex,
    BroadcastProvider provider,
  ) {
    switch (provider) {
      case BroadcastProvider.local:
        return lbtcLnSwap.broadcastLocal(
          signedHex: signedTxHex,
        );
      case BroadcastProvider.boltz:
        return lbtcLnSwap.broadcastBoltz(
          signedHex: signedTxHex,
        );
    }
  }

  // SUBMARINE SWAPS
}

extension EnvironmentToChain on Environment {
  Chain toBtcChain() {
    return this == Environment.mainnet ? Chain.bitcoin : Chain.bitcoinTestnet;
  }

  Chain toLbtcChain() {
    return this == Environment.mainnet ? Chain.liquid : Chain.liquidTestnet;
  }
}
