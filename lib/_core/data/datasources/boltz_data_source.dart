import 'dart:convert';

import 'package:bb_mobile/_core/data/datasources/key_value_stores/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/data/models/swap_model.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_utils/constants.dart';
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
  Future<void> storeMetadata(SwapModel swap);
  Future<SwapModel?> getMetadata(String swapId);
  Future<List<SwapModel>> getAllMetadata();
  Future<void> deleteMetadata(String swapId);
  Future<void> storeBtcLnSwap(BtcLnSwap swap);
  Future<void> storeLbtcLnSwap(LbtcLnSwap swap);
  Future<void> storeChainSwap(ChainSwap swap);
  Future<BtcLnSwap> getBtcLnSwap(String swapId);
  Future<LbtcLnSwap> getLbtcLnSwap(String swapId);
  Future<ChainSwap> getChainSwap(String swapId);
}

class BoltzDataSourceImpl implements BoltzDataSource {
  final String _url;
  final KeyValueStorageDataSource<String> _localSwapStorage;
  final KeyValueStorageDataSource _secureSwapStorage;

  BoltzDataSourceImpl({
    required KeyValueStorageDataSource<String> swapStorage,
    required KeyValueStorageDataSource<String> sensitiveSwapStorage,
    String url = ApiServiceConstants.boltzMainnetUrlPath,
  })  : _url = url,
        _localSwapStorage = swapStorage,
        _secureSwapStorage = sensitiveSwapStorage;

  // LOCAL STORAGE
  @override
  Future<void> storeMetadata(SwapModel swap) async {
    final swapJsonMap = swap.toJson();
    final jsonString = jsonEncode(swapJsonMap);
    await _localSwapStorage.saveValue(key: swap.id, value: jsonString);
  }

  @override
  Future<SwapModel?> getMetadata(String swapId) async {
    final jsonString = await _localSwapStorage.getValue(swapId);
    if (jsonString == null) {
      return null;
    }
    final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
    return SwapModel.fromJson(jsonMap);
  }

  @override
  Future<List<SwapModel>> getAllMetadata() async {
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
  Future<void> deleteMetadata(String swapId) async {
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
}

extension EnvironmentToChain on Environment {
  Chain toBtcChain() {
    return this == Environment.mainnet ? Chain.bitcoin : Chain.bitcoinTestnet;
  }

  Chain toLbtcChain() {
    return this == Environment.mainnet ? Chain.liquid : Chain.liquidTestnet;
  }
}
