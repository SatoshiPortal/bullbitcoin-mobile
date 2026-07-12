import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:joinstr_flutter/joinstr_flutter.dart' as jns;

/// Wraps the joinstr bindings. Everything above this layer works in satoshis
/// and domain entities; the `Ffi*` types and the BTC-denominated pool config
/// do not escape it.
class JoinstrDatasource {
  const JoinstrDatasource();

  Future<List<JoinstrPool>> listPools({
    required String relay,
    required Duration back,
    required Duration wait,
  }) async {
    final pools = await jns.listPools(
      back: BigInt.from(back.inSeconds),
      timeout: BigInt.from(wait.inMicroseconds),
      relay: relay,
    );

    // `FfiPool.network` is not trustworthy: pools published by the rust
    // implementation omit the field, so it decodes as mainnet regardless of
    // origin. It is deliberately not mapped onto the domain entity.
    return pools
        .map(
          (p) => JoinstrPool(
            id: p.id,
            rawJson: p.rawJson,
            denominationSat: p.denominationSat.toInt(),
            peers: p.peers,
            expiresAtUnixSec: p.expiresAtUnixSec.toInt(),
            relay: p.relay,
            feeRateSatPerVb: p.feeRate,
            publicKey: p.publicKey,
          ),
        )
        .toList();
  }

  /// Blocks until the coinjoin broadcasts or the pool times out, then returns
  /// the txid.
  Future<String> joinPool({
    required JoinstrPool pool,
    required Wallet wallet,
    required String mnemonic,
    required String outputAddress,
    required String electrumUrl,
  }) async {
    final peer = await _peerConfig(
      wallet: wallet,
      mnemonic: mnemonic,
      outputAddress: outputAddress,
      electrumUrl: electrumUrl,
      relay: pool.relay,
      denominationSat: pool.denominationSat,
    );

    return jns.joinCoinjoin(poolRawJson: pool.rawJson, peer: peer);
  }

  Future<String> initiatePool({
    required Wallet wallet,
    required String mnemonic,
    required String outputAddress,
    required String electrumUrl,
    required String relay,
    required int denominationSat,
    required int feeRateSatPerVb,
    required int peers,
    required Duration maxDuration,
  }) async {
    final peer = await _peerConfig(
      wallet: wallet,
      mnemonic: mnemonic,
      outputAddress: outputAddress,
      electrumUrl: electrumUrl,
      relay: relay,
      denominationSat: denominationSat,
    );

    return jns.initiateCoinjoin(
      config: jns.FfiPoolConfig(
        denominationBtc: Joinstr.denominationBtc(denominationSat),
        fee: feeRateSatPerVb,
        maxDuration: BigInt.from(maxDuration.inSeconds),
        peers: peers,
        network: _network(wallet.network),
      ),
      peer: peer,
    );
  }

  Future<jns.FfiPeerConfig> _peerConfig({
    required Wallet wallet,
    required String mnemonic,
    required String outputAddress,
    required String electrumUrl,
    required String relay,
    required int denominationSat,
  }) async {
    final endpoint = Joinstr.parseElectrumUrl(electrumUrl);
    final network = _network(wallet.network);

    final coins = await jns.listCoins(
      mnemonic: mnemonic,
      electrumAddress: endpoint.address,
      electrumPort: endpoint.port,
      rangeStart: 0,
      rangeEnd: Joinstr.scanDepth,
      network: network,
    );

    // The window is enforced by every other peer only *after* we broadcast a
    // SIGHASH_ALL|SIGHASH_ANYONECANPAY signature over the coin, so an
    // ineligible coin must never reach the signer.
    final index = Joinstr.selectEligibleCoin(
      coinValuesSat: coins.map((c) => c.valueSat.toInt()).toList(),
      denominationSat: denominationSat,
    );
    if (index == null) {
      throw JoinstrException(
        JoinstrIssue.noEligibleCoin,
        denominationSat: denominationSat,
      );
    }

    return jns.FfiPeerConfig(
      mnemonic: mnemonic,
      electrumAddress: endpoint.address,
      electrumPort: endpoint.port,
      input: coins[index],
      outputAddress: outputAddress,
      relay: relay,
      network: network,
    );
  }

  jns.BitcoinNetwork _network(Network network) => switch (network) {
    Network.bitcoinMainnet => jns.BitcoinNetwork.bitcoin,
    Network.bitcoinTestnet => jns.BitcoinNetwork.testnet,
    Network.liquidMainnet ||
    Network.liquidTestnet => throw JoinstrException(JoinstrIssue.bitcoinOnly),
  };
}
