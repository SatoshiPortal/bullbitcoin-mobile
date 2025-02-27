import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:boltz/boltz.dart';

abstract class BoltzDataSource {
  Future<ReverseFeesAndLimits> getReverseFeesAndLimits();
  Future<BtcLnSwap> createBtcReverseSwap(
    String mnemonic,
    BigInt index,
    BigInt outAmount,
    Environment environment,
    String electrumUrl,
  );
  Future<LbtcLnSwap> createLBtcReverseSwap(
    String mnemonic,
    BigInt index,
    BigInt outAmount,
    Environment environment,
    String electrumUrl,
  );
}

class BoltzDataSourceImpl implements BoltzDataSource {
  final String _url;

  BoltzDataSourceImpl({String url = 'api.boltz.exchange/v2'}) : _url = url;

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
    // TODO: make this conversion a helper
    // QUESTION: where should the conversion from Environment to chain take place?
    final network = environment == Environment.mainnet
        ? Chain.bitcoin
        : Chain.bitcoinTestnet;

    return await BtcLnSwap.newReverse(
      mnemonic: mnemonic,
      index: index,
      outAmount: outAmount,
      network: network,
      electrumUrl: electrumUrl,
      boltzUrl: _url,
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
    final network = environment == Environment.mainnet
        ? Chain.bitcoin
        : Chain.bitcoinTestnet;
    return await LbtcLnSwap.newReverse(
      mnemonic: mnemonic,
      index: index,
      outAmount: outAmount,
      network: network,
      electrumUrl: electrumUrl,
      boltzUrl: _url,
    );
  }
}
