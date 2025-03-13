import 'dart:convert';

import 'package:bb_mobile/_core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/data/models/swap_model.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart' as swap;
import 'package:bb_mobile/_utils/constants.dart';
import 'package:boltz/boltz.dart';

abstract class BoltzDataSource {
  // Reverse Swaps
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
    bool broadcastViaBoltz,
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
    bool broadcastViaBoltz,
  );
  // Submarine Swaps
  Future<SubmarineFeesAndLimits> getSubmarineFeesAndLimits();
  Future<BtcLnSwap> createBtcSubmarineSwap(
    String mnemonic,
    BigInt index,
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
    int absoluteFees,
    bool tryCooperate,
  );
  Future<LbtcLnSwap> createLbtcSubmarineSwap(
    String mnemonic,
    BigInt index,
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
    int absoluteFees,
    bool tryCooperate,
  );

  // Chain Swap
  Future<ChainFeesAndLimits> getChainFeesAndLimits();
  Future<ChainSwap> createBtcToLbtcChainSwap(
    String mnemonic,
    BigInt index,
    int amountSat,
    Environment environment,
    String btcElectrumUrl,
    String lbtcElectrumUrl,
  );
  Future<ChainSwap> createLbtcToBtcChainSwap(
    String mnemonic,
    BigInt index,
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
    int absoluteFees,
    bool tryCooperate,
  );

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> claimLbtcToBtcChainSwap(
    ChainSwap chainSwap,
    String claimBitcoinAddress,
    String refundLiquidAddress,
    int absoluteFees,
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
    int absoluteFees,
    bool tryCooperate,
  );

  /// Returns a signed tx hex which needs to be broadcasted
  Future<String> refundLbtcToBtcChainSwap(
    ChainSwap chainSwap,
    String refundLiquidAddress,
    int absoluteFees,
    bool tryCooperate,
  );

  Future<String> broadcastChainSwapRefund(
    ChainSwap chainSwap,
    String signedTxHex,
    bool broadcastViaBoltz,
  );

  // Swap Actions
  Future<swap.NextSwapAction> getBtcLnSwapAction(
    BtcLnSwap btcLnSwap,
    String status,
  );
  Future<swap.NextSwapAction> getLbtcLnSwapAction(
    LbtcLnSwap lbtcLnSwap,
    String status,
  );
  Future<swap.NextSwapAction> getChainSwapAction(
    ChainSwap chainSwap,
    String status,
  );

  // Local Storage
  Future<void> store(SwapModel swap);
  Future<SwapModel?> get(String swapId);
  Future<List<SwapModel>> getAll();
  Future<void> delete(String swapId);
  // Secure Storage
  Future<void> storeBtcLnSwap(BtcLnSwap swap);
  Future<void> storeLbtcLnSwap(LbtcLnSwap swap);
  Future<void> storeChainSwap(ChainSwap swap);
  Future<BtcLnSwap> getBtcLnSwap(String swapId);
  Future<LbtcLnSwap> getLbtcLnSwap(String swapId);
  Future<ChainSwap> getChainSwap(String swapId);
  // Future<void> deleteSecureSwap(String swapId);
}

class BoltzDataSourceImpl implements BoltzDataSource {
  final String _url;
  final KeyValueStorageDataSource<String> _localSwapStorage;
  final KeyValueStorageDataSource _secureSwapStorage;

  BoltzDataSourceImpl({
    required KeyValueStorageDataSource<String> localSwapStorage,
    required KeyValueStorageDataSource<String> secureSwapStorage,
    String url = ApiServiceConstants.boltzMainnetUrlPath,
  })  : _url = url,
        _localSwapStorage = localSwapStorage,
        _secureSwapStorage = secureSwapStorage;

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
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
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
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
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
    BigInt index,
    String invoice,
    Environment environment,
    String electrumUrl,
  ) async {
    return BtcLnSwap.newSubmarine(
      mnemonic: mnemonic,
      index: index,
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
    int absoluteFees,
    bool tryCooperate,
  ) async {
    return btcLnSwap.refund(
      outAddress: refundAddress,
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<LbtcLnSwap> createLbtcSubmarineSwap(
    String mnemonic,
    BigInt index,
    String invoice,
    Environment environment,
    String electrumUrl,
  ) async {
    return LbtcLnSwap.newSubmarine(
      mnemonic: mnemonic,
      index: index,
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
    int absoluteFees,
    bool tryCooperate,
  ) async {
    return lbtcLnSwap.refund(
      outAddress: refundAddress,
      minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
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
    BigInt index,
    int amountSat,
    Environment environment,
    String btcElectrumUrl,
    String lbtcElectrumUrl,
  ) async {
    return ChainSwap.newSwap(
      mnemonic: mnemonic,
      index: index,
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
    BigInt index,
    int amountSat,
    Environment environment,
    String btcElectrumUrl,
    String lbtcElectrumUrl,
  ) async {
    return ChainSwap.newSwap(
      mnemonic: mnemonic,
      index: index,
      boltzUrl: _url,
      direction: ChainSwapDirection.lbtcToBtc,
      amount: BigInt.from(amountSat),
      isTestnet: environment == Environment.testnet,
      btcElectrumUrl: btcElectrumUrl,
      lbtcElectrumUrl: lbtcElectrumUrl,
    );
  }

  // LOCAL STORAGE
  @override
  Future<void> store(SwapModel swap) async {
    final swapJsonMap = swap.toJson();
    final jsonString = jsonEncode(swapJsonMap);
    await _localSwapStorage.saveValue(key: swap.id, value: jsonString);
  }

  @override
  Future<SwapModel?> get(String swapId) async {
    final jsonString = await _localSwapStorage.getValue(swapId);
    if (jsonString == null) {
      return null;
    }
    final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
    return SwapModel.fromJson(jsonMap);
  }

  @override
  Future<List<SwapModel>> getAll() async {
    final allEntries = await _localSwapStorage.getAll();
    final swaps = <SwapModel>[];
    for (final jsonString in allEntries.values) {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final swap = SwapModel.fromJson(jsonMap);
      swaps.add(swap);
    }
    return swaps;
  }

  @override
  Future<void> delete(String swapId) async {
    await _localSwapStorage.deleteValue(swapId);
  }

  // SECURE STORAGE
  @override
  Future<void> storeBtcLnSwap(BtcLnSwap swap) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
    final jsonSwap = await swap.toJson();
    await _secureSwapStorage.saveValue(key: key, value: jsonSwap);
  }

  @override
  Future<void> storeLbtcLnSwap(LbtcLnSwap swap) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
    final jsonSwap = await swap.toJson();
    await _secureSwapStorage.saveValue(key: key, value: jsonSwap);
  }

  @override
  Future<void> storeChainSwap(ChainSwap swap) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
    final jsonSwap = await swap.toJson();
    await _secureSwapStorage.saveValue(key: key, value: jsonSwap);
  }

  @override
  Future<BtcLnSwap> getBtcLnSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return BtcLnSwap.fromJson(jsonStr: jsonSwap);
  }

  @override
  Future<LbtcLnSwap> getLbtcLnSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return LbtcLnSwap.fromJson(jsonStr: jsonSwap);
  }

  @override
  Future<ChainSwap> getChainSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return ChainSwap.fromJson(jsonStr: jsonSwap);
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
    int absoluteFees,
    bool tryCooperate,
  ) async {
    return await chainSwap.claim(
      outAddress: claimLiquidAddress,
      refundAddress: refundBitcoinAddress,
      absFee: BigInt.from(absoluteFees),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<String> claimLbtcToBtcChainSwap(
    ChainSwap chainSwap,
    String claimBitcoinAddress,
    String refundLiquidAddress,
    int absoluteFees,
    bool tryCooperate,
  ) async {
    return await chainSwap.claim(
      outAddress: claimBitcoinAddress,
      refundAddress: refundLiquidAddress,
      absFee: BigInt.from(absoluteFees),
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
    int absoluteFees,
    bool tryCooperate,
  ) async {
    return await chainSwap.refund(
      refundAddress: refundBitcoinAddress,
      absFee: BigInt.from(absoluteFees),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<String> refundLbtcToBtcChainSwap(
    ChainSwap chainSwap,
    String refundLiquidAddress,
    int absoluteFees,
    bool tryCooperate,
  ) async {
    return await chainSwap.refund(
      refundAddress: refundLiquidAddress,
      absFee: BigInt.from(absoluteFees),
      tryCooperate: tryCooperate,
    );
  }

  @override
  Future<swap.NextSwapAction> getBtcLnSwapAction(
    BtcLnSwap btcLnSwap,
    String status,
  ) async {
    final action = await btcLnSwap.process(status: status);
    switch (action) {
      // TODO: abstract as a enum extention
      case SwapAction.wait:
        return swap.NextSwapAction.wait;
      case SwapAction.coopSign:
        return swap.NextSwapAction.coopSign;
      case SwapAction.claim:
        return swap.NextSwapAction.claim;
      case SwapAction.refund:
        return swap.NextSwapAction.refund;
      case SwapAction.close:
        return swap.NextSwapAction.close;
    }
  }

  @override
  Future<swap.NextSwapAction> getChainSwapAction(
    ChainSwap chainSwap,
    String status,
  ) async {
    // TODO: implement getChainSwapAction
    final action = await chainSwap.process(status: status);
    switch (action) {
      // TODO: abstract as a enum extention
      case SwapAction.wait:
        return swap.NextSwapAction.wait;
      case SwapAction.coopSign:
        return swap.NextSwapAction.coopSign;
      case SwapAction.claim:
        return swap.NextSwapAction.claim;
      case SwapAction.refund:
        return swap.NextSwapAction.refund;
      case SwapAction.close:
        return swap.NextSwapAction.close;
    }
  }

  @override
  Future<swap.NextSwapAction> getLbtcLnSwapAction(
    LbtcLnSwap lbtcLnSwap,
    String status,
  ) async {
    // TODO: implement getLbtcLnSwapAction
    final action = await lbtcLnSwap.process(status: status);
    switch (action) {
      // TODO: abstract as a enum extention
      case SwapAction.wait:
        return swap.NextSwapAction.wait;
      case SwapAction.coopSign:
        return swap.NextSwapAction.coopSign;
      case SwapAction.claim:
        return swap.NextSwapAction.claim;
      case SwapAction.refund:
        return swap.NextSwapAction.refund;
      case SwapAction.close:
        return swap.NextSwapAction.close;
    }
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
