import 'package:bb_mobile/_core/data/datasources/boltz_storage_data_source.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart' as swap_entity;
import 'package:bb_mobile/_utils/constants.dart';
import 'package:boltz/boltz.dart';

abstract class BoltzDataSource {
  // Reverse Swaps
  Future<ReverseFeesAndLimits> getReverseFeesAndLimits();
  Future<BtcLnSwap> createBtcReverseSwap(
    String mnemonic,
    int index,
    int outAmount,
    Environment environment,
    String electrumUrl,
  );

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> claimBtcReverseSwap(
    BtcLnSwap btcLnSwap,
    String claimAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  );
  Future<String> broadcastBtcLnSwap(
    BtcLnSwap btcLnSwap,
    String signedTxHex,
    bool broadcastViaBoltz,
  );
  Future<LbtcLnSwap> createLBtcReverseSwap(
    String mnemonic,
    int index,
    int outAmount,
    Environment environment,
    String electrumUrl,
  );

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> claimLBtcReverseSwap(
    LbtcLnSwap lbtcLnSwap,
    String claimAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  );
  Future<String> broadcastLbtcLnSwap(
    LbtcLnSwap lbtcLnSwap,
    String signedTxHex,
    bool broadcastViaBoltz,
  );
  // Submarine Swaps
  Future<SubmarineFeesAndLimits> getSubmarineFeesAndLimits();
  Future<BtcLnSwap> createBtcSubmarineSwap(
    String mnemonic,
    int index,
    String invoice,
    Environment environment,
    String electrumUrl,
  );
  Future<void> coopSignBtcSubmarineSwap(BtcLnSwap btcLnSwap);
  // TODO: add function to get invoice preimage
  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> refundBtcSubmarineSwap(
    BtcLnSwap btcLnSwap,
    String refundAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  );
  Future<LbtcLnSwap> createLbtcSubmarineSwap(
    String mnemonic,
    int index,
    String invoice,
    Environment environment,
    String electrumUrl,
  );
  Future<void> coopSignLbtcSubmarineSwap(LbtcLnSwap lbtcLnSwap);
  // TODO: add function to get invoice preimage
  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> refundLbtcSubmarineSwap(
    LbtcLnSwap lbtcLnSwap,
    String refundAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  );

  // Chain Swap
  Future<ChainFeesAndLimits> getChainFeesAndLimits();
  Future<ChainSwap> createBtcToLbtcChainSwap(
    String mnemonic,
    int index,
    int amountSat,
    Environment environment,
    String btcElectrumUrl,
    String lbtcElectrumUrl,
  );
  Future<ChainSwap> createLbtcToBtcChainSwap(
    String mnemonic,
    int index,
    int amountSat,
    Environment environment,
    String btcElectrumUrl,
    String lbtcElectrumUrl,
  );

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> claimBtcToLbtcChainSwap(
    ChainSwap chainSwap,
    String claimLiquidAddress,
    String refundBitcoinAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  );

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> claimLbtcToBtcChainSwap(
    ChainSwap chainSwap,
    String claimBitcoinAddress,
    String refundLiquidAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  );
  Future<String> broadcastChainSwapClaim(
    ChainSwap chainSwap,
    String signedTxHex,
    bool broadcastViaBoltz,
  );

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> refundBtcToLbtcChainSwap(
    ChainSwap chainSwap,
    String refundBitcoinAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  );

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> refundLbtcToBtcChainSwap(
    ChainSwap chainSwap,
    String refundLiquidAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  );

  Future<String> broadcastChainSwapRefund(
    ChainSwap chainSwap,
    String signedTxHex,
    bool broadcastViaBoltz,
  );

  // Swap Actions
  Future<swap_entity.NextSwapAction> getBtcLnSwapAction(
    BtcLnSwap btcLnSwap,
    String status,
  );
  Future<swap_entity.NextSwapAction> getLbtcLnSwapAction(
    LbtcLnSwap lbtcLnSwap,
    String status,
  );
  Future<swap_entity.NextSwapAction> getChainSwapAction(
    ChainSwap chainSwap,
    String status,
  );
  // Websocket
  Stream<SwapStreamStatus> get stream;
  void initializBoltzWebSocket();
  void subscribeToSwaps(List<String> swapIds);
  void unsubscribeToSwaps(List<String> swapIds);
  void resetStream();
  // STORAGE
  BoltzStorageDataSourceImpl get storage;
}

class BoltzDataSourceImpl implements BoltzDataSource {
  final String _url;

  late BoltzWebSocket _boltzWebSocket;
  final BoltzStorageDataSourceImpl _boltzStore;

  BoltzDataSourceImpl({
    String url = ApiServiceConstants.boltzMainnetUrlPath,
    required BoltzStorageDataSourceImpl boltzStore,
  })  : _url = url,
        _boltzStore = boltzStore {
    initializBoltzWebSocket();
  }

  BoltzStorageDataSourceImpl get storage => _boltzStore;
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
    int index,
    int outAmount,
    Environment environment,
    String electrumUrl,
  ) async {
    return BtcLnSwap.newReverse(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      outAmount: BigInt.from(outAmount),
      network: environment.toBtcChain(),
      electrumUrl: electrumUrl,
      boltzUrl: _url,
    );
  }

  @override
  Future<String> claimBtcReverseSwap(
    BtcLnSwap btcLnSwap,
    String claimAddress,
    swap_entity.NetworkFees fees,
    bool tryCooperate,
  ) async {
    return btcLnSwap.claim(
      outAddress: claimAddress,
      minerFee: fees.toTxFee(),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<LbtcLnSwap> createLBtcReverseSwap(
    String mnemonic,
    int index,
    int outAmount,
    Environment environment,
    String electrumUrl,
  ) async {
    return LbtcLnSwap.newReverse(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      outAmount: BigInt.from(outAmount),
      network: environment.toLbtcChain(),
      electrumUrl: electrumUrl,
      boltzUrl: _url,
    );
  }

  @override
  Future<String> claimLBtcReverseSwap(
    LbtcLnSwap lbtcLnSwap,
    String claimAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  ) async {
    return lbtcLnSwap.claim(
      outAddress: claimAddress,
      minerFee: minerFee.toTxFee(),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<String> broadcastBtcLnSwap(
    BtcLnSwap btcLnSwap,
    String signedTxHex,
    bool broadcastViaBoltz,
  ) {
    return broadcastViaBoltz
        ? btcLnSwap.broadcastLocal(
            signedHex: signedTxHex,
          )
        : btcLnSwap.broadcastBoltz(
            signedHex: signedTxHex,
          );
  }

  @override
  Future<String> broadcastLbtcLnSwap(
    LbtcLnSwap lbtcLnSwap,
    String signedTxHex,
    bool broadcastViaBoltz,
  ) {
    return broadcastViaBoltz
        ? lbtcLnSwap.broadcastLocal(
            signedHex: signedTxHex,
          )
        : lbtcLnSwap.broadcastBoltz(
            signedHex: signedTxHex,
          );
  }

  // SUBMARINE SWAPS
  @override
  Future<SubmarineFeesAndLimits> getSubmarineFeesAndLimits() async {
    final fees = Fees(boltzUrl: _url);
    final submarine = await fees.submarine();
    return submarine;
  }

  @override
  Future<BtcLnSwap> createBtcSubmarineSwap(
    String mnemonic,
    int index,
    String invoice,
    Environment environment,
    String electrumUrl,
  ) async {
    return BtcLnSwap.newSubmarine(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      invoice: invoice,
      network: environment.toBtcChain(),
      electrumUrl: electrumUrl,
      boltzUrl: _url,
    );
  }

  @override
  Future<void> coopSignBtcSubmarineSwap(BtcLnSwap btcLnSwap) async {
    return btcLnSwap.coopCloseSubmarine();
  }

  @override
  Future<String> refundBtcSubmarineSwap(
    BtcLnSwap btcLnSwap,
    String refundAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  ) async {
    return btcLnSwap.refund(
      outAddress: refundAddress,
      minerFee: minerFee.toTxFee(),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<LbtcLnSwap> createLbtcSubmarineSwap(
    String mnemonic,
    int index,
    String invoice,
    Environment environment,
    String electrumUrl,
  ) async {
    return LbtcLnSwap.newSubmarine(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      invoice: invoice,
      network: environment.toBtcChain(),
      electrumUrl: electrumUrl,
      boltzUrl: _url,
    );
  }

  @override
  Future<void> coopSignLbtcSubmarineSwap(LbtcLnSwap lbtcLnSwap) async {
    return lbtcLnSwap.coopCloseSubmarine();
  }

  @override
  Future<String> refundLbtcSubmarineSwap(
    LbtcLnSwap lbtcLnSwap,
    String refundAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  ) async {
    return lbtcLnSwap.refund(
      outAddress: refundAddress,
      minerFee: minerFee.toTxFee(),
      tryCooperate: tryCooperate,
    );
  }

  // CHAIN SWAPS
  @override
  Future<ChainFeesAndLimits> getChainFeesAndLimits() async {
    final fees = Fees(boltzUrl: _url);
    final chain = await fees.chain();
    return chain;
  }

  @override
  Future<ChainSwap> createBtcToLbtcChainSwap(
    String mnemonic,
    int index,
    int amountSat,
    Environment environment,
    String btcElectrumUrl,
    String lbtcElectrumUrl,
  ) async {
    return ChainSwap.newSwap(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      boltzUrl: _url,
      direction: ChainSwapDirection.btcToLbtc,
      amount: BigInt.from(amountSat),
      isTestnet: environment == Environment.testnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
    );
  }

  @override
  Future<ChainSwap> createLbtcToBtcChainSwap(
    String mnemonic,
    int index,
    int amountSat,
    Environment environment,
    String btcElectrumUrl,
    String lbtcElectrumUrl,
  ) async {
    return ChainSwap.newSwap(
      mnemonic: mnemonic,
      index: BigInt.from(index),
      boltzUrl: _url,
      direction: ChainSwapDirection.lbtcToBtc,
      amount: BigInt.from(amountSat),
      isTestnet: environment == Environment.testnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
    );
  }

  @override
  Future<String> broadcastChainSwapRefund(
    ChainSwap chainSwap,
    String signedTxHex,
    bool broadcastViaBoltz,
  ) {
    return broadcastViaBoltz
        ? chainSwap.broadcastLocal(
            signedHex: signedTxHex,
            kind: SwapTxKind.refund,
          )
        : chainSwap.broadcastBoltz(
            signedHex: signedTxHex,
            kind: SwapTxKind.refund,
          );
  }

  @override
  Future<String> claimBtcToLbtcChainSwap(
    ChainSwap chainSwap,
    String claimLiquidAddress,
    String refundBitcoinAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  ) async {
    return await chainSwap.claim(
      outAddress: claimLiquidAddress,
      refundAddress: refundBitcoinAddress,
      minerFee: minerFee.toTxFee(),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<String> claimLbtcToBtcChainSwap(
    ChainSwap chainSwap,
    String claimBitcoinAddress,
    String refundLiquidAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  ) async {
    return await chainSwap.claim(
      outAddress: claimBitcoinAddress,
      refundAddress: refundLiquidAddress,
      minerFee: minerFee.toTxFee(),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<String> broadcastChainSwapClaim(
    ChainSwap chainSwap,
    String signedTxHex,
    bool broadcastViaBoltz,
  ) {
    return broadcastViaBoltz
        ? chainSwap.broadcastLocal(
            signedHex: signedTxHex,
            kind: SwapTxKind.claim,
          )
        : chainSwap.broadcastBoltz(
            signedHex: signedTxHex,
            kind: SwapTxKind.claim,
          );
  }

  @override
  Future<String> refundBtcToLbtcChainSwap(
    ChainSwap chainSwap,
    String refundBitcoinAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  ) async {
    return await chainSwap.refund(
      refundAddress: refundBitcoinAddress,
      minerFee: minerFee.toTxFee(),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<String> refundLbtcToBtcChainSwap(
    ChainSwap chainSwap,
    String refundLiquidAddress,
    swap_entity.NetworkFees minerFee,
    bool tryCooperate,
  ) async {
    return await chainSwap.refund(
      refundAddress: refundLiquidAddress,
      minerFee: minerFee.toTxFee(),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<swap_entity.NextSwapAction> getBtcLnSwapAction(
    BtcLnSwap btcLnSwap,
    String status,
  ) async {
    final action = await btcLnSwap.process(status: status);
    switch (action) {
      case SwapAction.wait:
        return swap_entity.NextSwapAction.wait;
      case SwapAction.coopSign:
        return swap_entity.NextSwapAction.coopSign;
      case SwapAction.claim:
        return swap_entity.NextSwapAction.claim;
      case SwapAction.refund:
        return swap_entity.NextSwapAction.refund;
      case SwapAction.close:
        return swap_entity.NextSwapAction.close;
    }
  }

  @override
  Future<swap_entity.NextSwapAction> getChainSwapAction(
    ChainSwap chainSwap,
    String status,
  ) async {
    final action = await chainSwap.process(status: status);
    switch (action) {
      case SwapAction.wait:
        return swap_entity.NextSwapAction.wait;
      case SwapAction.coopSign:
        return swap_entity.NextSwapAction.coopSign;
      case SwapAction.claim:
        return swap_entity.NextSwapAction.claim;
      case SwapAction.refund:
        return swap_entity.NextSwapAction.refund;
      case SwapAction.close:
        return swap_entity.NextSwapAction.close;
    }
  }

  @override
  Future<swap_entity.NextSwapAction> getLbtcLnSwapAction(
    LbtcLnSwap lbtcLnSwap,
    String status,
  ) async {
    final action = await lbtcLnSwap.process(status: status);
    switch (action) {
      case SwapAction.wait:
        return swap_entity.NextSwapAction.wait;
      case SwapAction.coopSign:
        return swap_entity.NextSwapAction.coopSign;
      case SwapAction.claim:
        return swap_entity.NextSwapAction.claim;
      case SwapAction.refund:
        return swap_entity.NextSwapAction.refund;
      case SwapAction.close:
        return swap_entity.NextSwapAction.close;
    }
  }

  /// WEB SOCKET STREAM
  @override
  Future<void> initializBoltzWebSocket() async {
    try {
      _boltzWebSocket = BoltzWebSocket.create(_url);
    } catch (e) {
      print('Error creating BoltzWebSocket: $e');
      rethrow;
    }
  }

  @override
  Stream<SwapStreamStatus> get stream => _boltzWebSocket.stream;

  @override
  void resetStream() {
    _boltzWebSocket.dispose();
    initializBoltzWebSocket();
  }

  @override
  void subscribeToSwaps(List<String> swapIds) {
    _boltzWebSocket.subscribe(swapIds);
  }

  @override
  void unsubscribeToSwaps(List<String> swapIds) {
    _boltzWebSocket.unsubscribe(swapIds);
  }
}

extension EnvironmentToChain on Environment {
  Chain toBtcChain() {
    return this == Environment.mainnet ? Chain.bitcoin : Chain.bitcoinTestnet;
  }

  Chain toLbtcChain() {
    return this == Environment.mainnet ? Chain.liquid : Chain.liquidTestnet;
  }
}

extension NetworkFeesX on swap_entity.NetworkFees {
  TxFee toTxFee() {
    return when(
      absolute: (value) => TxFee.absolute(BigInt.from(value)),
      relative: (value) => TxFee.relative(value),
    );
  }
}
