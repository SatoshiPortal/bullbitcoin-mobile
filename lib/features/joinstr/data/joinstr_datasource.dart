import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_coin.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_progress.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';
import 'package:joinstr_flutter/joinstr_flutter.dart' as jns;

/// Wraps the joinstr bindings. Everything above this layer works in satoshis
/// and domain entities; the `Ffi*` types and the BTC-denominated pool config
/// do not escape it.
class JoinstrDatasource {
  const JoinstrDatasource();

  /// Runs an FFI call, translating the binding's `JoinstrError` into a domain
  /// [JoinstrException] that carries its real message. Without this the error
  /// surfaces as `JoinstrError.toString()`, i.e. "Instance of 'JoinstrError'".
  Future<T> _call<T>(Future<T> Function() ffi) async {
    // Loads the native library on first use; memoized and retry-safe in the
    // bindings, so app startup does not pay for it.
    await jns.JoinstrFlutter.init();
    try {
      return await ffi();
    } on jns.JoinstrError catch (e) {
      throw JoinstrException(JoinstrIssue.coinjoinFailed, detail: e.message);
    }
  }

  Future<List<JoinstrPool>> listPools({
    required String relay,
    required Duration back,
    required Duration wait,
    String? proxy,
  }) async {
    final pools = await _call(
      () => jns.listPools(
        back: BigInt.from(back.inSeconds),
        timeout: BigInt.from(wait.inMicroseconds),
        relay: relay,
        proxy: proxy,
      ),
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

  /// Lists the wallet's spendable coins by scanning electrum over Tor. The
  /// caller filters these to the coins eligible for a given denomination.
  Future<List<JoinstrCoin>> listCoins({
    required Wallet wallet,
    required String mnemonic,
    required String electrumUrl,
    String? proxy,
  }) async {
    final endpoint = Joinstr.parseElectrumUrl(electrumUrl);
    final coins = await _call(
      () => jns.listCoins(
        mnemonic: mnemonic,
        electrumAddress: endpoint.address,
        electrumPort: endpoint.port,
        rangeStart: 0,
        rangeEnd: Joinstr.scanDepth,
        network: _network(wallet.network),
        proxy: proxy,
      ),
    );
    return coins
        .map(
          (c) => JoinstrCoin(
            txid: c.txid,
            vout: c.vout,
            valueSat: c.valueSat.toInt(),
          ),
        )
        .toList();
  }

  /// Streams coinjoin progress until it broadcasts or the pool times out.
  Stream<JoinstrProgress> joinPool({
    required JoinstrPool pool,
    required Wallet wallet,
    required String mnemonic,
    required String outputAddress,
    required String electrumUrl,
    required String inputOutpoint,
    String? proxy,
  }) async* {
    final peer = await _peerConfig(
      wallet: wallet,
      mnemonic: mnemonic,
      outputAddress: outputAddress,
      electrumUrl: electrumUrl,
      relay: pool.relay,
      denominationSat: pool.denominationSat,
      inputOutpoint: inputOutpoint,
      proxy: proxy,
    );
    yield* _run(jns.joinCoinjoin(poolRawJson: pool.rawJson, peer: peer));
  }

  Stream<JoinstrProgress> initiatePool({
    required Wallet wallet,
    required String mnemonic,
    required String outputAddress,
    required String electrumUrl,
    required String relay,
    required int denominationSat,
    required int feeRateSatPerVb,
    required int peers,
    required Duration maxDuration,
    required String inputOutpoint,
    String? proxy,
  }) async* {
    final peer = await _peerConfig(
      wallet: wallet,
      mnemonic: mnemonic,
      outputAddress: outputAddress,
      electrumUrl: electrumUrl,
      relay: relay,
      denominationSat: denominationSat,
      inputOutpoint: inputOutpoint,
      proxy: proxy,
    );
    yield* _run(
      jns.initiateCoinjoin(
        config: jns.FfiPoolConfig(
          denominationBtc: Joinstr.denominationBtc(denominationSat),
          fee: feeRateSatPerVb,
          maxDuration: BigInt.from(maxDuration.inSeconds),
          peers: peers,
          network: _network(wallet.network),
        ),
        peer: peer,
      ),
    );
  }

  /// Maps the binding's progress stream onto the domain, translating a binding
  /// error into a [JoinstrException] the way [_call] does for one-shot calls.
  Stream<JoinstrProgress> _run(Stream<jns.FfiCoinjoinUpdate> updates) async* {
    try {
      await for (final u in updates) {
        yield JoinstrProgress(
          step: _step(u.step),
          txId: u.txid,
          errorMessage: u.error,
        );
      }
    } on jns.JoinstrError catch (e) {
      throw JoinstrException(JoinstrIssue.coinjoinFailed, detail: e.message);
    }
  }

  JoinstrRoundStep _step(jns.FfiCoinjoinStep step) => switch (step) {
    jns.FfiCoinjoinStep.connecting => JoinstrRoundStep.connecting,
    jns.FfiCoinjoinStep.posting => JoinstrRoundStep.posting,
    jns.FfiCoinjoinStep.outputRegistration =>
      JoinstrRoundStep.outputRegistration,
    jns.FfiCoinjoinStep.inputRegistration => JoinstrRoundStep.inputRegistration,
    jns.FfiCoinjoinStep.broadcast => JoinstrRoundStep.broadcast,
    jns.FfiCoinjoinStep.mined => JoinstrRoundStep.mined,
    jns.FfiCoinjoinStep.done => JoinstrRoundStep.done,
    jns.FfiCoinjoinStep.failed => JoinstrRoundStep.failed,
    jns.FfiCoinjoinStep.other => JoinstrRoundStep.other,
  };

  Future<jns.FfiPeerConfig> _peerConfig({
    required Wallet wallet,
    required String mnemonic,
    required String outputAddress,
    required String electrumUrl,
    required String relay,
    required int denominationSat,
    required String inputOutpoint,
    String? proxy,
  }) async {
    await jns.JoinstrFlutter.init();
    final endpoint = Joinstr.parseElectrumUrl(electrumUrl);
    final network = _network(wallet.network);

    final coins = await jns.listCoins(
      mnemonic: mnemonic,
      electrumAddress: endpoint.address,
      electrumPort: endpoint.port,
      rangeStart: 0,
      rangeEnd: Joinstr.scanDepth,
      network: network,
      proxy: proxy,
    );

    // Use the coin the user picked. Re-listing here keeps it fresh: a coin that
    // was spent since the picker loaded is simply gone from the wallet.
    jns.FfiCoin? input;
    for (final c in coins) {
      if ('${c.txid}:${c.vout}' == inputOutpoint) {
        input = c;
        break;
      }
    }
    if (input == null) {
      throw JoinstrException(JoinstrIssue.coinUnavailable);
    }

    // The window is enforced by every other peer only *after* we broadcast a
    // SIGHASH_ALL|SIGHASH_ANYONECANPAY signature over the coin, so an
    // ineligible coin must never reach the signer.
    if (!Joinstr.isEligibleCoin(
      valueSat: input.valueSat.toInt(),
      denominationSat: denominationSat,
    )) {
      throw JoinstrException(
        JoinstrIssue.noEligibleCoin,
        denominationSat: denominationSat,
      );
    }

    return jns.FfiPeerConfig(
      mnemonic: mnemonic,
      electrumAddress: endpoint.address,
      electrumPort: endpoint.port,
      input: input,
      outputAddress: outputAddress,
      relay: relay,
      network: network,
      proxy: proxy,
    );
  }

  jns.BitcoinNetwork _network(Network network) => switch (network) {
    Network.bitcoinMainnet => jns.BitcoinNetwork.bitcoin,
    Network.bitcoinTestnet => jns.BitcoinNetwork.testnet,
    Network.liquidMainnet ||
    Network.liquidTestnet => throw JoinstrException(JoinstrIssue.bitcoinOnly),
  };
}
