import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_master_key_model.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_tx_outspend_model.dart';
import 'package:bb_mobile/core/swaps/data/services/swap_status_mapper.dart';
import 'package:bb_mobile/core/swaps/domain/entity/boltz_network.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart' as swap_entity;
import 'package:bb_mobile/core/swaps/domain/entity/swap_tx_outspend.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:boltz_stream/boltz_stream.dart';
import 'package:dio/dio.dart';
import 'package:bull_sdk/boltz.dart' hide Network;
import 'package:bull_sdk/boltz.dart' as boltz;

/// The current default wallet's fingerprint plus a lazy accessor for its
/// mnemonic. The fingerprint keys the swap master key in storage; the mnemonic
/// is read/derived only on a cache miss.
typedef DefaultSwapWallet =
    ({String fingerprint, Future<String> Function() mnemonic});

class BoltzDatasource {
  final String _baseUrl;
  late String _httpsUrl;
  late final Dio _http;

  late BoltzWebSocket _boltzWebSocket;
  final BoltzStorageDatasource _boltzStore;

  /// Resolves the current default wallet (fingerprint + lazy mnemonic) the swap
  /// master key is derived from. The swap master key MUST always come from this
  /// one canonical seed — see [_ensureSwapMasterKey].
  final Future<DefaultSwapWallet> Function() _defaultSwapWallet;
  final SwapStatusMapper _mapper = const SwapStatusMapper();
  final Set<String> _subscribedSwapIds = {};

  final Map<String, Future<void>> _eventChains = {};

  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  final StreamController<SwapModel> _swapUpdatesController =
      StreamController<SwapModel>.broadcast();

  static const _feesTtl = Duration(minutes: 5);
  ReverseFeesAndLimits? _reverseFeesAndLimits;
  SubmarineFeesAndLimits? _submarineFeesAndLimits;
  ChainFeesAndLimits? _chainFeesAndLimits;
  DateTime? _reverseFeesFetchedAt;
  DateTime? _submarineFeesFetchedAt;
  DateTime? _chainFeesFetchedAt;

  BoltzDatasource({
    String url = ApiServiceConstants.boltzMainnetUrlPath,
    required this._boltzStore,
    required this._defaultSwapWallet,
  }) : _baseUrl = url {
    _httpsUrl = 'https://$_baseUrl';
    _http = Dio(BaseOptions(baseUrl: _httpsUrl));
    _initializeBoltzWebSocket();
  }

  Future<void> updateFees({required swap_entity.SwapType swapType}) async {
    final allFees = Fees(boltzUrl: _httpsUrl);
    switch (swapType) {
      case swap_entity.SwapType.lightningToBitcoin:
      case swap_entity.SwapType.lightningToLiquid:
        _reverseFeesAndLimits = await allFees.reverse();
        _reverseFeesFetchedAt = DateTime.now();
      case swap_entity.SwapType.bitcoinToLightning:
      case swap_entity.SwapType.liquidToLightning:
        _submarineFeesAndLimits = await allFees.submarine();
        _submarineFeesFetchedAt = DateTime.now();
      case swap_entity.SwapType.bitcoinToLiquid:
      case swap_entity.SwapType.liquidToBitcoin:
        _chainFeesAndLimits = await allFees.chain();
        _chainFeesFetchedAt = DateTime.now();
    }
  }

  bool _isStale(DateTime? fetchedAt) =>
      fetchedAt == null || DateTime.now().difference(fetchedAt) > _feesTtl;

  BoltzStorageDatasource get storage => _boltzStore;

  Stream<SwapModel> get swapUpdatesStream => _swapUpdatesController.stream;

  Future<swap_entity.SwapFees> getSwapFees(swap_entity.SwapType type) async {
    if (type.isReverse &&
        (_reverseFeesAndLimits == null || _isStale(_reverseFeesFetchedAt))) {
      await updateFees(swapType: type);
    }
    if (type.isSubmarine &&
        (_submarineFeesAndLimits == null ||
            _isStale(_submarineFeesFetchedAt))) {
      await updateFees(swapType: type);
    }
    if (type.isChain &&
        (_chainFeesAndLimits == null || _isStale(_chainFeesFetchedAt))) {
      await updateFees(swapType: type);
    }
    switch (type) {
      case swap_entity.SwapType.lightningToBitcoin:
        final fees = _reverseFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.btcFees.percentage as double?,
          lockupFee: fees.btcFees.minerFees.lockup.toInt() as int?,
          claimFee: fees.btcFees.minerFees.claim.toInt() as int?,
        );
      case swap_entity.SwapType.lightningToLiquid:
        final fees = _reverseFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.lbtcFees.percentage as double?,
          lockupFee: fees.lbtcFees.minerFees.lockup.toInt() as int?,
          claimFee: fees.lbtcFees.minerFees.claim.toInt() as int?,
        );
      case swap_entity.SwapType.bitcoinToLightning:
        final fees = _submarineFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.btcFees.percentage as double?,
          lockupFee: fees.btcFees.minerFees.toInt() as int?,
          claimFee: fees.btcFees.minerFees.toInt() as int?,
        );
      case swap_entity.SwapType.liquidToLightning:
        final fees = _submarineFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.lbtcFees.percentage as double?,
          lockupFee: fees.lbtcFees.minerFees.toInt() as int?,
          claimFee: fees.lbtcFees.minerFees.toInt() as int?,
        );
      case swap_entity.SwapType.bitcoinToLiquid:
        final fees = _chainFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.btcToLbtcFees.percentage as double?,
          lockupFee: fees.btcToLbtcFees.userLockup.toInt() as int?,
          claimFee: ((fees.btcToLbtcFees.userClaim.toInt() as int?) ?? 0) + 3,
          serverNetworkFees: fees.btcToLbtcFees.server.toInt() as int?,
        );
      case swap_entity.SwapType.liquidToBitcoin:
        final fees = _chainFeesAndLimits!;
        return swap_entity.SwapFees(
          boltzPercent: fees.lbtcToBtcFees.percentage as double?,
          lockupFee: fees.lbtcToBtcFees.userLockup.toInt() as int?,
          claimFee: fees.lbtcToBtcFees.userClaim.toInt() as int?,
          serverNetworkFees: fees.lbtcToBtcFees.server.toInt() as int?,
        );
    }
  }

  // SWAP MASTER KEY
  //
  // The key is derived (BIP85) from the CURRENT default wallet's seed and cached
  // in secure storage keyed by that wallet's fingerprint — never by network
  // alone. Keying by fingerprint is what makes restore correct: a swap can be
  // created from any wallet, but the key always resolves from the one default
  // seed, and a different default wallet (or a stale key the iOS keychain kept
  // after the app was deleted) can never be mistaken for the current wallet's.
  Future<SwapMasterKeyModel> ensureSwapMasterKey({required bool isTestnet}) =>
      _ensureSwapMasterKey(isTestnet);

  Future<SwapMasterKeyModel> _ensureSwapMasterKey(bool isTestnet) async {
    final network = isTestnet ? BoltzNetwork.testnet : BoltzNetwork.mainnet;
    final wallet = await _defaultSwapWallet();
    if (await _boltzStore.swapMasterKeyExists(
      network,
      walletFingerprint: wallet.fingerprint,
    )) {
      return _boltzStore.fetchSwapMasterKey(
        network,
        walletFingerprint: wallet.fingerprint,
      );
    }
    final model = await SwapMasterKeyModel.create(
      mnemonic: await wallet.mnemonic(),
      isTestnet: isTestnet,
    );
    await _boltzStore.storeSwapMasterKey(
      model,
      walletFingerprint: wallet.fingerprint,
    );
    return model;
  }

  // RESTORE — thin wrappers over the new boltz restore API; driven by usecases
  // in a later pass.

  // One restore call returning id/kind/status/amount per swap — for listing.
  Future<List<RestoredSwapSummary>> restoreSwapSummaries({
    required SwapMasterKeyModel swapMasterKey,
  }) => boltz.restoreSwapSummaries(
    swapMasterKey: swapMasterKey.toBoltz(),
    boltzUrl: _httpsUrl,
  );

  Future<List<BtcLnSwap>> restoreBtcLnSwaps({
    required SwapMasterKeyModel swapMasterKey,
    required String electrumUrl,
  }) => boltz.restoreLnBtcSwaps(
    swapMasterKey: swapMasterKey.toBoltz(),
    electrumUrl: electrumUrl,
    boltzUrl: _httpsUrl,
  );

  Future<List<LbtcLnSwap>> restoreLbtcLnSwaps({
    required SwapMasterKeyModel swapMasterKey,
    required String electrumUrl,
  }) => boltz.restoreLnLbtcSwaps(
    swapMasterKey: swapMasterKey.toBoltz(),
    electrumUrl: electrumUrl,
    boltzUrl: _httpsUrl,
  );

  Future<List<ChainSwap>> restoreChainSwaps({
    required SwapMasterKeyModel swapMasterKey,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
  }) => boltz.restoreChainSwaps(
    swapMasterKey: swapMasterKey.toBoltz(),
    btcElectrumUrl: btcElectrumUrl,
    lbtcElectrumUrl: lbtcElectrumUrl,
    boltzUrl: _httpsUrl,
  );

  // REVERSE SWAPS
  Future<SwapModel> createBtcReverseSwap({
    required String walletId,
    required int index,
    required int outAmount,
    required bool isTestnet,
    required String electrumUrl,
    required String magicRouteHintAddress,
    String? description,
  }) async {
    try {
      if (_reverseFeesAndLimits == null || _isStale(_reverseFeesFetchedAt)) {
        await updateFees(swapType: swap_entity.SwapType.lightningToBitcoin);
      }
      final reverseFees = _reverseFeesAndLimits!;
      final btcLnSwap = await BtcLnSwap.newReverse(
        swapMasterKey: (await _ensureSwapMasterKey(isTestnet)).toBoltz(),
        index: BigInt.from(index),
        outAmount: BigInt.from(outAmount),
        network: isTestnet ? Chain.bitcoinTestnet : Chain.bitcoin,
        electrumUrl: electrumUrl,
        boltzUrl: _httpsUrl,
        outAddress: magicRouteHintAddress,
        description: description,
        referralId: ApiServiceConstants.boltzReferralId,
      );
      await _boltzStore.storeBtcLnSwap(btcLnSwap);
      final swapModel = SwapModel.lnReceive(
        id: btcLnSwap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swap_entity.SwapType.lightningToBitcoin.name,
        isTestnet: isTestnet,
        keyIndex: index,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        receiveWalletId: walletId,
        invoice: btcLnSwap.invoice,
        boltzFees:
            (reverseFees.btcFees.percentage * outAmount / 100).ceil() as int?,
        lockupFees: reverseFees.btcFees.minerFees.lockup.toInt() as int?,
        claimFees: reverseFees.btcFees.minerFees.claim.toInt() as int?,
        receiveAddress: magicRouteHintAddress,
      );
      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);
      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> claimBtcReverseSwap({
    required String swapId,
    required String claimAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final btcLnSwap = await _boltzStore.fetchBtcLnSwap(swapId);

      return await btcLnSwap.claim(
        outAddress: claimAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<SwapModel> createLBtcReverseSwap({
    required String walletId,
    required int index,
    required int outAmount,
    required bool isTestnet,
    required String electrumUrl,
    required String magicRouteHintAddress,
    String? description,
  }) async {
    try {
      if (_reverseFeesAndLimits == null || _isStale(_reverseFeesFetchedAt)) {
        await updateFees(swapType: swap_entity.SwapType.lightningToLiquid);
      }
      final reverseFees = _reverseFeesAndLimits!;
      final lbtcLnSwap = await LbtcLnSwap.newReverse(
        swapMasterKey: (await _ensureSwapMasterKey(isTestnet)).toBoltz(),
        index: BigInt.from(index),
        outAmount: BigInt.from(outAmount),
        network: isTestnet ? Chain.liquidTestnet : Chain.liquid,
        electrumUrl: electrumUrl,
        boltzUrl: _httpsUrl,
        outAddress: magicRouteHintAddress,
        description: description,
        referralId: ApiServiceConstants.boltzReferralId,
      );

      await _boltzStore.storeLbtcLnSwap(lbtcLnSwap);

      final swapModel = SwapModel.lnReceive(
        id: lbtcLnSwap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swap_entity.SwapType.lightningToLiquid.name,
        isTestnet: isTestnet,
        keyIndex: index,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        receiveWalletId: walletId,
        invoice: lbtcLnSwap.invoice,
        boltzFees:
            (reverseFees.lbtcFees.percentage * outAmount / 100).ceil() as int?,
        lockupFees: reverseFees.lbtcFees.minerFees.lockup.toInt() as int?,
        claimFees: reverseFees.lbtcFees.minerFees.claim.toInt() as int?,
        receiveAddress: magicRouteHintAddress,
      );

      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);

      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> claimLBtcReverseSwap({
    required String swapId,
    required String claimAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final lbtcLnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);

      return await lbtcLnSwap.claim(
        outAddress: claimAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> broadcastBtcLnSwap({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    try {
      final btcLnSwap = await _boltzStore.fetchBtcLnSwap(swapId);

      return broadcastViaBoltz
          ? btcLnSwap.broadcastBoltz(signedHex: signedTxHex)
          : btcLnSwap.broadcastLocal(signedHex: signedTxHex);
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> broadcastLbtcLnSwap({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    try {
      final lbtcLnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);

      return broadcastViaBoltz
          ? lbtcLnSwap.broadcastBoltz(signedHex: signedTxHex)
          : lbtcLnSwap.broadcastLocal(signedHex: signedTxHex);
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<SwapModel> createBtcSubmarineSwap({
    required String walletId,
    required int index,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    try {
      if (_submarineFeesAndLimits == null ||
          _isStale(_submarineFeesFetchedAt)) {
        await updateFees(swapType: swap_entity.SwapType.bitcoinToLightning);
      }
      final submarineFees = _submarineFeesAndLimits!;
      final btcLnSwap = await BtcLnSwap.newSubmarine(
        swapMasterKey: (await _ensureSwapMasterKey(isTestnet)).toBoltz(),
        index: BigInt.from(index),
        invoice: invoice,
        network: isTestnet ? Chain.bitcoinTestnet : Chain.bitcoin,
        electrumUrl: electrumUrl,
        boltzUrl: _httpsUrl,
        referralId: ApiServiceConstants.boltzReferralId,
      );

      await _boltzStore.storeBtcLnSwap(btcLnSwap);

      final swapModel = SwapModel.lnSend(
        id: btcLnSwap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swap_entity.SwapType.bitcoinToLightning.name,
        isTestnet: isTestnet,
        keyIndex: index,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        sendWalletId: walletId,
        invoice: invoice,
        paymentAddress: btcLnSwap.scriptAddress,
        paymentAmount: btcLnSwap.outAmount.toInt(),
        boltzFees:
            (submarineFees.btcFees.percentage *
                        (btcLnSwap.outAmount.toInt()) /
                        100)
                    .ceil()
                as int?,
        lockupFees: submarineFees.btcFees.minerFees.toInt() as int?,
        claimFees: submarineFees.btcFees.minerFees.toInt() as int?,
      );
      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);

      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<SwapModel> createLbtcSubmarineSwap({
    required String walletId,
    required int index,
    required String invoice,
    required bool isTestnet,
    required String electrumUrl,
  }) async {
    try {
      if (_submarineFeesAndLimits == null ||
          _isStale(_submarineFeesFetchedAt)) {
        await updateFees(swapType: swap_entity.SwapType.liquidToLightning);
      }
      final submarineFees = _submarineFeesAndLimits!;
      final lbtcLnSwap = await LbtcLnSwap.newSubmarine(
        swapMasterKey: (await _ensureSwapMasterKey(isTestnet)).toBoltz(),
        index: BigInt.from(index),
        invoice: invoice,
        network: isTestnet ? Chain.liquidTestnet : Chain.liquid,
        electrumUrl: electrumUrl,
        boltzUrl: _httpsUrl,
        referralId: ApiServiceConstants.boltzReferralId,
      );

      await _boltzStore.storeLbtcLnSwap(lbtcLnSwap);

      final swapModel = SwapModel.lnSend(
        id: lbtcLnSwap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swap_entity.SwapType.liquidToLightning.name,
        isTestnet: isTestnet,
        keyIndex: index,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        sendWalletId: walletId,
        invoice: invoice,
        paymentAddress: lbtcLnSwap.scriptAddress,
        paymentAmount: lbtcLnSwap.outAmount.toInt(),
        boltzFees:
            (submarineFees.lbtcFees.percentage *
                        (lbtcLnSwap.outAmount.toInt()) /
                        100)
                    .ceil()
                as int?,
        lockupFees: submarineFees.lbtcFees.minerFees.toInt() as int?,
        claimFees: submarineFees.lbtcFees.minerFees.toInt() as int?,
      );

      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);

      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<void> coopSignBtcSubmarineSwap({required String swapId}) async {
    try {
      final btcLnSwap = await _boltzStore.fetchBtcLnSwap(swapId);
      return await btcLnSwap.coopCloseSubmarine();
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<void> coopSignLbtcSubmarineSwap({required String swapId}) async {
    try {
      final lbtcLnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);
      await lbtcLnSwap.coopCloseSubmarine();
      return;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> refundBtcSubmarineSwap({
    required String swapId,
    required String refundAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final btcLnSwap = await _boltzStore.fetchBtcLnSwap(swapId);
      return await btcLnSwap.refund(
        outAddress: refundAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> refundLbtcSubmarineSwap({
    required String swapId,
    required String refundAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final lbtcLnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);
      return await lbtcLnSwap.refund(
        outAddress: refundAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String?> getBtcLnSwapPreimage({required String swapId}) async {
    try {
      final btcLnSwap = await _boltzStore.fetchBtcLnSwap(swapId);
      return await btcLnSwap.getPreimage();
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String?> getLbtcLnSwapPreimage({required String swapId}) async {
    try {
      final lbtcLnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);
      return await lbtcLnSwap.getPreimage();
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<SwapModel> createBtcToLbtcChainSwap({
    required String sendWalletId,
    required int index,
    required int amountSat,
    required bool isTestnet,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    try {
      if (_chainFeesAndLimits == null || _isStale(_chainFeesFetchedAt)) {
        await updateFees(swapType: swap_entity.SwapType.bitcoinToLiquid);
      }
      final chainFees = _chainFeesAndLimits!;
      final chainSwap = await ChainSwap.newSwap(
        swapMasterKey: (await _ensureSwapMasterKey(isTestnet)).toBoltz(),
        index: BigInt.from(index),
        boltzUrl: _httpsUrl,
        direction: ChainSwapDirection.btcToLbtc,
        amount: BigInt.from(amountSat),
        isTestnet: isTestnet,
        btcElectrumUrl: btcElectrumUrl,
        lbtcElectrumUrl: lbtcElectrumUrl,
        referralId: ApiServiceConstants.boltzReferralId,
      );

      await _boltzStore.storeChainSwap(chainSwap);
      final swapModel = SwapModel.chain(
        id: chainSwap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swap_entity.SwapType.bitcoinToLiquid.name,
        isTestnet: isTestnet,
        keyIndex: index,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        sendWalletId: sendWalletId,
        receiveWalletId: receiveWalletId,
        paymentAddress: chainSwap.scriptAddress,
        paymentAmount: chainSwap.outAmount.toInt(),
        receiveAddress: externalRecipientAddress,
        boltzFees:
            (chainFees.btcToLbtcFees.percentage * amountSat / 100).ceil()
                as int?,
        lockupFees: chainFees.btcToLbtcFees.userLockup.toInt() as int?,
        claimFees:
            ((chainFees.btcToLbtcFees.userClaim.toInt() as int?) ?? 0) + 3,
        serverNetworkFees: chainFees.btcToLbtcFees.server.toInt() as int?,
      );
      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);
      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<SwapModel> createLbtcToBtcChainSwap({
    required String sendWalletId,
    required int index,
    required int amountSat,
    required bool isTestnet,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    try {
      if (_chainFeesAndLimits == null || _isStale(_chainFeesFetchedAt)) {
        await updateFees(swapType: swap_entity.SwapType.liquidToBitcoin);
      }
      final chainFees = _chainFeesAndLimits!;

      final chainSwap = await ChainSwap.newSwap(
        swapMasterKey: (await _ensureSwapMasterKey(isTestnet)).toBoltz(),
        index: BigInt.from(index),
        boltzUrl: _httpsUrl,
        direction: ChainSwapDirection.lbtcToBtc,
        amount: BigInt.from(amountSat),
        isTestnet: isTestnet,
        btcElectrumUrl: btcElectrumUrl,
        lbtcElectrumUrl: lbtcElectrumUrl,
        referralId: ApiServiceConstants.boltzReferralId,
      );

      await _boltzStore.storeChainSwap(chainSwap);

      final swapModel = SwapModel.chain(
        id: chainSwap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swap_entity.SwapType.liquidToBitcoin.name,
        isTestnet: isTestnet,
        keyIndex: index,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        sendWalletId: sendWalletId,
        receiveWalletId: receiveWalletId,
        paymentAddress: chainSwap.scriptAddress,
        paymentAmount: chainSwap.outAmount.toInt(),
        receiveAddress: externalRecipientAddress,
        boltzFees:
            (chainFees.lbtcToBtcFees.percentage * amountSat / 100).ceil()
                as int?,
        lockupFees: chainFees.lbtcToBtcFees.userLockup.toInt() as int?,
        claimFees: chainFees.lbtcToBtcFees.userClaim.toInt() as int?,
        serverNetworkFees: chainFees.lbtcToBtcFees.server.toInt() as int?,
      );
      await _boltzStore.store(swapModel);
      subscribeToSwaps([swapModel.id]);

      return swapModel;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> broadcastChainSwapRefund({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);
      final txId = await (broadcastViaBoltz
          ? chainSwap.broadcastBoltz(
              signedHex: signedTxHex,
              kind: SwapTxKind.refund,
            )
          : chainSwap.broadcastLocal(
              signedHex: signedTxHex,
              kind: SwapTxKind.refund,
            ));
      return txId;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> claimBtcToLbtcChainSwap({
    required String swapId,
    required String claimLiquidAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);
      return await chainSwap.claim(
        outAddress: claimLiquidAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> claimLbtcToBtcChainSwap({
    required String swapId,
    required String claimBitcoinAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);
      return await chainSwap.claim(
        outAddress: claimBitcoinAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> broadcastChainSwapClaim({
    required String swapId,
    required String signedTxHex,
    required bool broadcastViaBoltz,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);
      return await (broadcastViaBoltz
          ? chainSwap.broadcastBoltz(
              signedHex: signedTxHex,
              kind: SwapTxKind.claim,
            )
          : chainSwap.broadcastLocal(
              signedHex: signedTxHex,
              kind: SwapTxKind.claim,
            ));
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> refundBtcToLbtcChainSwap({
    required String swapId,
    required String refundBitcoinAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);
      return await chainSwap.refund(
        refundAddress: refundBitcoinAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<String> refundLbtcToBtcChainSwap({
    required String swapId,
    required String refundLiquidAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    try {
      final chainSwap = await _boltzStore.fetchChainSwap(swapId);

      final signedTxHex = await chainSwap.refund(
        refundAddress: refundLiquidAddress,
        minerFee: TxFee.absolute(BigInt.from(absoluteFees)),
        tryCooperate: tryCooperate,
      );
      return signedTxHex;
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<(int, int)> getBtcReverseSwapLimits() async {
    if (_reverseFeesAndLimits == null || _isStale(_reverseFeesFetchedAt)) {
      await updateFees(swapType: swap_entity.SwapType.lightningToBitcoin);
    }
    final reverse = _reverseFeesAndLimits!;
    return (
      reverse.btcLimits.minimal.toInt(),
      reverse.btcLimits.maximal.toInt(),
    );
  }

  Future<(int, int)> getLbtcReverseSwapLimits() async {
    if (_reverseFeesAndLimits == null || _isStale(_reverseFeesFetchedAt)) {
      await updateFees(swapType: swap_entity.SwapType.lightningToLiquid);
    }
    final reverse = _reverseFeesAndLimits!;
    return (
      reverse.lbtcLimits.minimal.toInt(),
      reverse.lbtcLimits.maximal.toInt(),
    );
  }

  Future<(int, int)> getBtcSubmarineSwapLimits() async {
    if (_submarineFeesAndLimits == null || _isStale(_submarineFeesFetchedAt)) {
      await updateFees(swapType: swap_entity.SwapType.bitcoinToLightning);
    }
    final submarine = _submarineFeesAndLimits!;
    return (
      submarine.btcLimits.minimal.toInt(),
      submarine.btcLimits.maximal.toInt(),
    );
  }

  Future<(int, int)> getLbtcSubmarineSwapLimits() async {
    if (_submarineFeesAndLimits == null || _isStale(_submarineFeesFetchedAt)) {
      await updateFees(swapType: swap_entity.SwapType.liquidToLightning);
    }
    final submarine = _submarineFeesAndLimits!;
    return (
      submarine.lbtcLimits.minimal.toInt(),
      submarine.lbtcLimits.maximal.toInt(),
    );
  }

  Future<(int, int)> getBtcToLbtcChainSwapLimits() async {
    if (_chainFeesAndLimits == null || _isStale(_chainFeesFetchedAt)) {
      await updateFees(swapType: swap_entity.SwapType.bitcoinToLiquid);
    }
    final chain = _chainFeesAndLimits!;
    return (
      chain.btcToLbtcLimits.minimal.toInt(),
      chain.btcToLbtcLimits.maximal.toInt(),
    );
  }

  Future<(int, int)> getLbtcToBtcChainSwapLimits() async {
    if (_chainFeesAndLimits == null || _isStale(_chainFeesFetchedAt)) {
      await updateFees(swapType: swap_entity.SwapType.liquidToBitcoin);
    }
    final chain = _chainFeesAndLimits!;
    return (
      chain.lbtcToBtcLimits.minimal.toInt(),
      chain.lbtcToBtcLimits.maximal.toInt(),
    );
  }

  Future<int> getBtcLnClaimTxSize({
    required String swapId,
    bool isCooperative = true,
  }) async {
    final lnSwap = await _boltzStore.fetchBtcLnSwap(swapId);
    final size = await lnSwap.claimTxSize(isCooperative: isCooperative);
    return size.toInt();
  }

  Future<int> getLbtcLnClaimTxSize({
    required String swapId,
    bool isCooperative = true,
  }) async {
    final lnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);
    final size = await lnSwap.claimTxSize(isCooperative: isCooperative);
    return size.toInt();
  }

  Future<int> getChainClaimTxSize({
    required String swapId,
    required String claimAddress,
    bool isCooperative = true,
  }) async {
    final chainSwap = await _boltzStore.fetchChainSwap(swapId);
    final size = await chainSwap.claimTxSize(
      outAddress: claimAddress,
      tryCooperate: isCooperative,
    );
    return size.toInt();
  }

  Future<int> getLbtLnRefundTxSize({
    required String swapId,
    bool isCooperative = true,
  }) async {
    final lnSwap = await _boltzStore.fetchLbtcLnSwap(swapId);
    final size = await lnSwap.refundTxSize(isCooperative: isCooperative);
    return size.toInt();
  }

  Future<int> getBtcLnRefundTxSize({
    required String swapId,
    bool isCooperative = true,
  }) async {
    final lnSwap = await _boltzStore.fetchBtcLnSwap(swapId);
    final size = await lnSwap.refundTxSize(isCooperative: isCooperative);
    return size.toInt();
  }

  Future<int> getChainRefundTxSize({
    required String swapId,
    required String refundAddress,
    bool isCooperative = true,
  }) async {
    final chainSwap = await _boltzStore.fetchChainSwap(swapId);
    final size = await chainSwap.refundTxSize(
      refundAddress: refundAddress,
      tryCooperate: isCooperative,
    );
    return size.toInt();
  }

  bool _swapNeedsProcessing(SwapModel swapModel) {
    final status = swap_entity.SwapStatus.values.firstWhere(
      (s) => s.name == swapModel.status,
      orElse: () => swap_entity.SwapStatus.pending,
    );

    switch (status) {
      case swap_entity.SwapStatus.claimable:
        if (swapModel is LnReceiveSwapModel) {
          return swapModel.receiveTxid == null;
        } else if (swapModel is ChainSwapModel) {
          return swapModel.receiveTxid == null;
        }
        return false;

      case swap_entity.SwapStatus.refundable:
        if (swapModel is LnSendSwapModel) {
          return swapModel.refundTxid == null;
        } else if (swapModel is ChainSwapModel) {
          return swapModel.refundTxid == null;
        }
        return false;

      case swap_entity.SwapStatus.canCoop:
        return true;

      default:
        return false;
    }
  }

  void _initializeBoltzWebSocket() {
    _boltzWebSocket = BoltzWebSocket.create(
      _baseUrl,
      onDone: () {
        log.warning('[Boltz] websocket closed unexpectedly');
        _scheduleReconnect();
      },
      onError: (error) {
        log.warning('[Boltz] websocket error: $error');
      },
    );

    _boltzWebSocket.stream.listen(
      (event) {
        _reconnectAttempt = 0;
        if (event.id.isEmpty) {
          // Connection-level error frames carry no swap id.
          log.warning('[Boltz] websocket error frame: ${event.error}');
          return;
        }
        log.fine('[Boltz] event swap=${event.id} status=${event.status.name}');
        _enqueueEvent(event.id, event.status, event.transaction?.id);
      },
      onError: (error) {
        _swapUpdatesController.addError(error.toString());
      },
      cancelOnError: false,
    );
  }

  /// On reconnect, reconcile each swap's status over REST: Boltz does not
  /// guarantee replay of events missed while disconnected.
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    final delaySeconds = min(60, 1 << min(_reconnectAttempt, 6));
    _reconnectAttempt++;
    log.warning(
      '[Boltz] reconnecting websocket in ${delaySeconds}s '
      '(attempt $_reconnectAttempt)',
    );
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      try {
        _boltzWebSocket.reconnect();
        final ids = _subscribedSwapIds.toList();
        _subscribedSwapIds.clear();
        subscribeToSwaps(ids);
        await reconcileSwaps(ids);
      } catch (e) {
        log.warning('[Boltz] websocket reconnect failed: $e');
        _scheduleReconnect();
      }
    });
  }

  Future<void> _enqueueEvent(
    String swapId,
    SwapStatus boltzStatus,
    String? transactionId,
  ) {
    final previous = _eventChains[swapId] ?? Future.value();
    final next = previous.then(
      (_) =>
          _processSwapEvent(swapId, boltzStatus, transactionId: transactionId),
    );
    _eventChains[swapId] = next;
    next.whenComplete(() {
      if (identical(_eventChains[swapId], next)) {
        _eventChains.remove(swapId);
      }
    });
    return next;
  }

  /// Fetches each swap's current status over REST and runs it through the same
  /// mapping pipeline as websocket events, so recovery never depends on Boltz
  /// replaying events missed while disconnected.
  Future<void> reconcileSwaps(List<String> swapIds) async {
    for (final swapId in swapIds) {
      try {
        final response = await _http.get<Map<String, dynamic>>('/swap/$swapId');
        final data = response.data;
        if (data == null) continue;
        final status = SwapStatusResponse.fromJson(json: jsonEncode(data));
        await _enqueueEvent(swapId, status.status, status.transaction?.id);
      } catch (e) {
        log.warning('[Boltz] reconcile failed for swap $swapId: $e');
      }
    }
  }

  /// Never throws: a failure here must not break the swap's event chain.
  Future<void> _processSwapEvent(
    String swapId,
    SwapStatus boltzStatus, {
    String? transactionId,
  }) async {
    try {
      var swapModel = await _boltzStore.fetch(swapId);
      if (swapModel == null) {
        unsubscribeToSwaps([swapId]);
        return;
      }

      var mapping = _mapper.map(
        swap: swapModel,
        boltzStatus: boltzStatus,
        transactionId: transactionId,
        now: DateTime.now(),
      );

      // The watcher writes concurrently with this event chain; re-fetch and
      // re-map if the row moved, so a store can't lose a txid or regress a
      // terminal status by writing back a stale row.
      if (mapping is! SwapUnchanged) {
        final latest = await _boltzStore.fetch(swapId);
        if (latest == null) {
          unsubscribeToSwaps([swapId]);
          return;
        }
        if (latest != swapModel) {
          swapModel = latest;
          mapping = _mapper.map(
            swap: swapModel,
            boltzStatus: boltzStatus,
            transactionId: transactionId,
            now: DateTime.now(),
          );
        }
      }

      switch (mapping) {
        case SwapStale():
          log.info(
            '[Boltz] deleting stale pending swap $swapId '
            '(no funds at risk, expired upstream)',
          );
          unsubscribeToSwaps([swapId]);
          await _boltzStore.trash(swapId);
          await _boltzStore.deleteFromSecureStorage(swapId);

        case SwapUnchanged():
          if (_isSettled(swapModel) && !_swapNeedsProcessing(swapModel)) {
            _swapUpdatesController.add(swapModel);
            unsubscribeToSwaps([swapId]);
          } else if (_swapNeedsProcessing(swapModel)) {
            // Status unchanged but the swap still needs a claim, refund or coop
            // close: re-emit so reconciliation un-sticks a missed action.
            _swapUpdatesController.add(swapModel);
          }

        case SwapUpdated(:final swap):
          await _boltzStore.store(swap);
          log.info(
            '[Boltz] swap $swapId: ${swapModel.status} -> ${swap.status} '
            '(event ${boltzStatus.name})',
          );
          _swapUpdatesController.add(swap);
          if (_isSettled(swap) && !_swapNeedsProcessing(swap)) {
            unsubscribeToSwaps([swapId]);
          }
      }
    } catch (e, st) {
      log.severe(
        message: '[Boltz] failed to process event for swap $swapId',
        error: e,
        trace: st,
      );
    }
  }

  /// True when no watcher action can ever apply again: completed/refunded,
  /// or expired/failed without locked-and-unrefunded funds.
  bool _isSettled(SwapModel swapModel) {
    final status = swap_entity.SwapStatus.values.firstWhere(
      (s) => s.name == swapModel.status,
      orElse: () => swap_entity.SwapStatus.pending,
    );
    switch (status) {
      case swap_entity.SwapStatus.completed:
        if (swapModel is LnReceiveSwapModel) {
          return swapModel.receiveTxid != null || swapModel.wasDirectPayment;
        }
        if (swapModel is ChainSwapModel) {
          return swapModel.receiveTxid != null || swapModel.refundTxid != null;
        }
        return true;
      case swap_entity.SwapStatus.refunded:
        return true;
      case swap_entity.SwapStatus.expired:
      case swap_entity.SwapStatus.failed:
        final sendTxid = switch (swapModel) {
          LnSendSwapModel(:final sendTxid) => sendTxid,
          ChainSwapModel(:final sendTxid) => sendTxid,
          LnReceiveSwapModel() => null,
        };
        final refundTxid = switch (swapModel) {
          LnSendSwapModel(:final refundTxid) => refundTxid,
          ChainSwapModel(:final refundTxid) => refundTxid,
          LnReceiveSwapModel() => null,
        };
        return sendTxid == null || refundTxid != null;
      case swap_entity.SwapStatus.pending:
      case swap_entity.SwapStatus.paid:
      case swap_entity.SwapStatus.claimable:
      case swap_entity.SwapStatus.refundable:
      case swap_entity.SwapStatus.canCoop:
        return false;
    }
  }

  Future<void> reconnect() async {
    resetStream();
  }

  void resetStream() {
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    _boltzWebSocket.dispose();
    _subscribedSwapIds.clear();
    _initializeBoltzWebSocket();
  }

  void subscribeToSwaps(List<String> swapIds) {
    final uniqueSwapIds = swapIds.toSet().toList();
    final newSwapIds = uniqueSwapIds
        .where((id) => !_subscribedSwapIds.contains(id))
        .toList();

    if (newSwapIds.isEmpty) {
      return;
    }
    _boltzWebSocket.subscribe(newSwapIds);
    _subscribedSwapIds.addAll(newSwapIds);
  }

  void unsubscribeToSwaps(List<String> swapIds) {
    final uniqueSwapIds = swapIds.toSet().toList();
    final swapIdsToUnsubscribe = uniqueSwapIds
        .where((id) => _subscribedSwapIds.contains(id))
        .toList();
    if (swapIdsToUnsubscribe.isEmpty) {
      return;
    }
    _boltzWebSocket.unsubscribe(swapIdsToUnsubscribe);
    _subscribedSwapIds.removeAll(swapIdsToUnsubscribe);
  }

  Future<(int, bool, String?)> decodeInvoice(String invoice) async {
    try {
      final decoded = await DecodedInvoice.fromString(
        s: invoice,
        boltzUrl: _httpsUrl,
      );
      final sats = (decoded.msats ~/ BigInt.from(1000)).toInt();
      return (sats, decoded.isExpired, decoded.bip21);
    } catch (e) {
      if (e is BoltzError) {
        throw e.message;
      } else {
        rethrow;
      }
    }
  }

  Future<void> fromBtcLnSwapObjectMigration(
    BtcLnSwap swap,
    String? receiveWalletId,
    String? sendWalletId,
    String? lockupTxid,
    String? claimAddress,
  ) async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final reverseFees = await fees.reverse();
    final submarineFees = await fees.submarine();
    final swapType = swap.kind == SwapType.reverse
        ? swap_entity.SwapType.lightningToBitcoin
        : swap_entity.SwapType.bitcoinToLightning;
    if (swapType == swap_entity.SwapType.lightningToBitcoin) {
      if (receiveWalletId == null) {
        throw 'Receive wallet ID is required for lightning to bitcoin swaps';
      }
      final swapModel = SwapModel.lnReceive(
        id: swap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swapType.name,
        keyIndex: swap.keyIndex.toInt(),
        receiveWalletId: receiveWalletId,
        invoice: swap.invoice,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        boltzFees:
            (reverseFees.btcFees.percentage * swap.outAmount.toInt() / 100)
                    .ceil()
                as int?,
        lockupFees: reverseFees.btcFees.minerFees.lockup.toInt() as int?,
        claimFees: reverseFees.btcFees.minerFees.claim.toInt() as int?,
        receiveAddress: claimAddress,
      );
      await _boltzStore.storeBtcLnSwap(swap);
      await _boltzStore.store(swapModel);
    }
    if (swapType == swap_entity.SwapType.bitcoinToLightning) {
      if (sendWalletId == null) {
        throw 'Send wallet ID is required for lightning to bitcoin swaps';
      }
      final swapModel = SwapModel.lnSend(
        id: swap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swapType.name,
        keyIndex: swap.keyIndex.toInt(),
        sendWalletId: sendWalletId,
        invoice: swap.invoice,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        paymentAddress: swap.scriptAddress,
        paymentAmount: swap.outAmount.toInt(),
        sendTxid: lockupTxid,
        boltzFees:
            (submarineFees.btcFees.percentage * (swap.outAmount.toInt()) / 100)
                    .ceil()
                as int?,
        lockupFees: submarineFees.btcFees.minerFees.toInt() as int?,
        claimFees: submarineFees.btcFees.minerFees.toInt() as int?,
      );
      await _boltzStore.storeBtcLnSwap(swap);
      await _boltzStore.store(swapModel);
    }
  }

  Future<void> fromLbtcLnSwapObjectMigration(
    LbtcLnSwap swap,
    String? receiveWalletId,
    String? sendWalletId,
    String? lockupTxid,
    String? claimAddress,
  ) async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final reverseFees = await fees.reverse();
    final submarineFees = await fees.submarine();
    final swapType = swap.kind == SwapType.reverse
        ? swap_entity.SwapType.lightningToLiquid
        : swap_entity.SwapType.liquidToLightning;
    if (swapType == swap_entity.SwapType.lightningToLiquid) {
      if (receiveWalletId == null) {
        throw 'Receive wallet ID is required for lightning to liquid swaps';
      }
      final swapModel = SwapModel.lnReceive(
        id: swap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swapType.name,
        keyIndex: swap.keyIndex.toInt(),
        receiveWalletId: receiveWalletId,
        invoice: swap.invoice,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        boltzFees:
            (reverseFees.lbtcFees.percentage * swap.outAmount.toInt() / 100)
                    .ceil()
                as int?,
        lockupFees: reverseFees.lbtcFees.minerFees.lockup.toInt() as int?,
        claimFees: reverseFees.lbtcFees.minerFees.claim.toInt() as int?,
        receiveAddress: claimAddress,
      );
      await _boltzStore.storeLbtcLnSwap(swap);
      await _boltzStore.store(swapModel);
    }
    if (swapType == swap_entity.SwapType.liquidToLightning) {
      if (sendWalletId == null) {
        throw 'Send wallet ID is required for lightning to liquid swaps';
      }
      final swapModel = SwapModel.lnSend(
        id: swap.id,
        status: swap_entity.SwapStatus.pending.name,
        type: swapType.name,
        keyIndex: swap.keyIndex.toInt(),
        sendWalletId: sendWalletId,
        invoice: swap.invoice,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        paymentAddress: swap.scriptAddress,
        paymentAmount: swap.outAmount.toInt(),
        sendTxid: lockupTxid,
        boltzFees:
            (submarineFees.lbtcFees.percentage * (swap.outAmount.toInt()) / 100)
                    .ceil()
                as int?,
        lockupFees: submarineFees.lbtcFees.minerFees.toInt() as int?,
        claimFees: submarineFees.lbtcFees.minerFees.toInt() as int?,
      );
      await _boltzStore.storeLbtcLnSwap(swap);
      await _boltzStore.store(swapModel);
    }
  }

  Future<void> fromChainSwapObjectMigration(
    ChainSwap swap,
    String sendWalletId,
    String receiveWalletId,
    bool isReceiveWalletExternal,
    String? lockupTxid,
  ) async {
    final fees = Fees(boltzUrl: _httpsUrl);
    final chainFees = await fees.chain();
    final swapType = swap.direction == ChainSwapDirection.lbtcToBtc
        ? swap_entity.SwapType.liquidToBitcoin
        : swap_entity.SwapType.bitcoinToLiquid;
    switch (swapType) {
      case swap_entity.SwapType.liquidToBitcoin:
        final swapModel = SwapModel.chain(
          id: swap.id,
          status: swap_entity.SwapStatus.pending.name,
          type: swapType.name,
          keyIndex: swap.claimIndex.toInt(),
          creationTime: DateTime.now().millisecondsSinceEpoch,
          sendWalletId: sendWalletId,
          paymentAddress: swap.scriptAddress,
          paymentAmount: swap.outAmount.toInt(),
          sendTxid: lockupTxid,
          receiveWalletId: isReceiveWalletExternal == false
              ? receiveWalletId
              : null,
          receiveAddress: isReceiveWalletExternal == true
              ? receiveWalletId
              : null,
          boltzFees:
              (chainFees.lbtcToBtcFees.percentage * swap.outAmount.toInt() / 100)
                      .ceil()
                  as int?,
          lockupFees: chainFees.lbtcToBtcFees.userLockup.toInt() as int?,
          claimFees: chainFees.lbtcToBtcFees.userClaim.toInt() as int?,
          serverNetworkFees: chainFees.lbtcToBtcFees.server.toInt() as int?,
        );
        await _boltzStore.storeChainSwap(swap);
        await _boltzStore.store(swapModel);
      case swap_entity.SwapType.bitcoinToLiquid:
        final swapModel = SwapModel.chain(
          id: swap.id,
          status: swap_entity.SwapStatus.pending.name,
          type: swapType.name,
          keyIndex: swap.claimIndex.toInt(),
          creationTime: DateTime.now().millisecondsSinceEpoch,
          sendWalletId: sendWalletId,
          paymentAddress: swap.scriptAddress,
          paymentAmount: swap.outAmount.toInt(),
          sendTxid: lockupTxid,
          receiveWalletId: isReceiveWalletExternal == false
              ? receiveWalletId
              : null,
          receiveAddress: isReceiveWalletExternal == true
              ? receiveWalletId
              : null,
          boltzFees:
              (chainFees.btcToLbtcFees.percentage * swap.outAmount.toInt() / 100)
                      .ceil()
                  as int?,
          lockupFees: chainFees.btcToLbtcFees.userLockup.toInt() as int?,
          claimFees: chainFees.btcToLbtcFees.userClaim.toInt() as int?,
          serverNetworkFees: chainFees.btcToLbtcFees.server.toInt() as int?,
        );
        await _boltzStore.storeChainSwap(swap);
        await _boltzStore.store(swapModel);
      default:
        throw Exception('Invalid swap type');
    }
  }

  /// Checks the outspend status of a swap's lockup transaction
  Future<SwapTxOutspendModel> checkSwapLockupOutspend({
    required String swapId,
    required swap_entity.SwapType swapType,
    required Network network,
    SwapDirection? swapDirection,
    bool isClaim = true,
  }) async {
    final boltzSwapType = switch (swapType) {
      swap_entity.SwapType.lightningToBitcoin ||
      swap_entity.SwapType.lightningToLiquid => SwapType.reverse,
      swap_entity.SwapType.bitcoinToLightning ||
      swap_entity.SwapType.liquidToLightning => SwapType.submarine,
      swap_entity.SwapType.bitcoinToLiquid ||
      swap_entity.SwapType.liquidToBitcoin => SwapType.chain,
    };

    final boltzChain = switch (network) {
      Network.bitcoinMainnet => Chain.bitcoin,
      Network.bitcoinTestnet => Chain.bitcoinTestnet,
      Network.liquidMainnet => Chain.liquid,
      Network.liquidTestnet => Chain.liquidTestnet,
    };

    final chainSwapDirection = swapDirection != null
        ? switch (swapDirection) {
            SwapDirection.bitcoinToLiquid => ChainSwapDirection.btcToLbtc,
            SwapDirection.liquidToBitcoin => ChainSwapDirection.lbtcToBtc,
          }
        : null;

    final outspendStatus = await checkVout0Outspend(
      swapId: swapId,
      swapType: boltzSwapType,
      txKind: isClaim ? SwapTxKind.claim : SwapTxKind.refund,
      network: boltzChain,
      boltzUrl: _httpsUrl,
      chainSwapDirection: chainSwapDirection,
    );

    return SwapTxOutspendModel(
      txid: outspendStatus.txid,
      timestamp: outspendStatus.timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(
              outspendStatus.timestamp!.toInt() * 1000,
            )
          : null,
    );
  }
}
