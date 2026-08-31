import 'dart:math';

import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:bull_swap/bull_swap.dart';
import 'package:primitives/primitives.dart';

typedef ElectrumUrlResolver =
    Future<String> Function(SwapNetwork network, SwapEnvironment environment);
typedef SwapFeeResolver =
    Future<double> Function(SwapNetwork network, SwapEnvironment environment);

class BoltzEngineAdapter implements BoltzEnginePort {
  final BoltzSwapRepository _repository;
  final ElectrumUrlResolver _electrumUrl;
  final SwapFeeResolver _feeRate;
  final GetReceiveAddressUsecase _getReceiveAddress;

  BoltzEngineAdapter(
    this._repository,
    this._electrumUrl,
    this._feeRate,
    this._getReceiveAddress,
  );

  @override
  Future<Result<SwapQuote, SwapFailure>> quote({
    required SwapNetwork inNetwork,
    required SwapNetwork outNetwork,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required SwapEnvironment environment,
  }) async {
    try {
      final type = _swapType(inNetwork, outNetwork);
      final (_, fees) = await _repository.getSwapLimitsAndFees(type);
      final amount = amountSat.toInt();
      final total = fees.totalFees(amount);
      final payout = amount - total;
      return Ok(
        SwapQuote(
          providerId: 'boltz',
          inNetwork: inNetwork,
          outNetwork: outNetwork,
          payinAmountSat: amountSat,
          payoutAmountSat: BigInt.from(payout < 0 ? 0 : payout),
          feesSat: BigInt.from(total),
        ),
      );
    } catch (error) {
      return Err(_map(error));
    }
  }

  @override
  Future<Result<CreatedSwap, SwapFailure>> createLnSend({
    required SwapNetwork fromNetwork,
    required String invoice,
    required String refundAddress,
    String? sourceWalletId,
    required SwapEnvironment environment,
  }) async {
    try {
      final walletId = _requireWallet(sourceWalletId);
      final electrum = await _electrumUrl(fromNetwork, environment);
      final swap = fromNetwork == SwapNetwork.liquid
          ? await _repository.createLiquidToLightningSwap(
              walletId: walletId,
              invoice: invoice,
              electrumUrl: electrum,
            )
          : await _repository.createBitcoinToLightningSwap(
              walletId: walletId,
              invoice: invoice,
              electrumUrl: electrum,
            );
      return Ok(_fromSend(swap, fromNetwork, environment));
    } catch (error) {
      return Err(_map(error));
    }
  }

  @override
  Future<Result<CreatedSwap, SwapFailure>> createLnReceive({
    required SwapNetwork toNetwork,
    required BigInt amountSat,
    required String payoutAddress,
    String? destinationWalletId,
    required SwapEnvironment environment,
  }) async {
    try {
      final walletId = _requireWallet(destinationWalletId);
      final electrum = await _electrumUrl(toNetwork, environment);
      final swap = toNetwork == SwapNetwork.liquid
          ? await _repository.createLightningToLiquidSwap(
              walletId: walletId,
              amountSat: amountSat.toInt(),
              electrumUrl: electrum,
              claimAddress: payoutAddress,
            )
          : await _repository.createLightningToBitcoinSwap(
              walletId: walletId,
              amountSat: amountSat.toInt(),
              electrumUrl: electrum,
              claimAddress: payoutAddress,
            );
      return Ok(_fromReceive(swap, toNetwork, amountSat, environment));
    } catch (error) {
      return Err(_map(error));
    }
  }

  @override
  Future<Result<CreatedSwap, SwapFailure>> createChainSwap({
    required SwapNetwork fromNetwork,
    required SwapNetwork toNetwork,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required String payoutAddress,
    required String refundAddress,
    String? sourceWalletId,
    String? destinationWalletId,
    required SwapEnvironment environment,
  }) async {
    try {
      final walletId = _requireWallet(sourceWalletId);
      final btcElectrum = await _electrumUrl(SwapNetwork.bitcoin, environment);
      final lbtcElectrum = await _electrumUrl(SwapNetwork.liquid, environment);
      final swap = fromNetwork == SwapNetwork.liquid
          ? await _repository.createLiquidToBitcoinSwap(
              sendWalletId: walletId,
              amountSat: amountSat.toInt(),
              btcElectrumUrl: btcElectrum,
              lbtcElectrumUrl: lbtcElectrum,
              receiveWalletId: destinationWalletId,
              externalRecipientAddress: destinationWalletId == null
                  ? payoutAddress
                  : null,
            )
          : await _repository.createBitcoinToLiquidSwap(
              sendWalletId: walletId,
              amountSat: amountSat.toInt(),
              btcElectrumUrl: btcElectrum,
              lbtcElectrumUrl: lbtcElectrum,
              receiveWalletId: destinationWalletId,
              externalRecipientAddress: destinationWalletId == null
                  ? payoutAddress
                  : null,
            );
      return Ok(_fromChain(swap, fromNetwork, toNetwork, environment));
    } catch (error) {
      return Err(_map(error));
    }
  }

  @override
  Future<Result<SwapStatusUpdate, SwapFailure>> refresh(
    String swapId, {
    required SwapEnvironment environment,
  }) async {
    try {
      final swap = await _repository.getSwap(swapId: swapId);
      return Ok(_status(swap));
    } catch (error) {
      return Err(_map(error));
    }
  }

  @override
  Stream<SwapStatusUpdate> watch(
    String swapId, {
    required SwapEnvironment environment,
  }) => _repository.watchSwap(swapId: swapId).map(_status);

  @override
  Future<Result<String, SwapFailure>> claim(
    String swapId, {
    required SwapEnvironment environment,
  }) async {
    try {
      final swap = await _repository.getSwap(swapId: swapId);
      final address = await _resolveClaimAddress(swap);
      final network = _claimNetwork(swap.type);
      final isLiquid = network == SwapNetwork.liquid;
      final rate = await _feeRate(network, environment);
      final chainAddress = swap.type.isChain ? address : null;
      Future<String> claimWith(bool cooperate, int fees) => switch (swap.type) {
        SwapType.lightningToBitcoin => _repository.claimLightningToBitcoinSwap(
          swapId: swapId,
          bitcoinAddress: address,
          absoluteFees: fees,
          cooperate: cooperate,
        ),
        SwapType.lightningToLiquid => _repository.claimLightningToLiquidSwap(
          swapId: swapId,
          liquidAddress: address,
          absoluteFees: fees,
          cooperate: cooperate,
        ),
        SwapType.liquidToBitcoin => _repository.claimLiquidToBitcoinSwap(
          swapId: swapId,
          bitcoinClaimAddress: address,
          absoluteFees: fees,
          cooperate: cooperate,
        ),
        SwapType.bitcoinToLiquid => _repository.claimBitcoinToLiquidSwap(
          swapId: swapId,
          liquidClaimAddress: address,
          absoluteFees: fees,
          cooperate: cooperate,
        ),
        _ => throw const _NotClaimable(),
      };
      return Ok(
        await _withCoopFallback(
          (cooperate) =>
              _claimFee(swap, isLiquid, rate, cooperate, chainAddress),
          claimWith,
        ),
      );
    } catch (error) {
      return Err(_map(error));
    }
  }

  /// Runs [attempt] cooperatively first, then falls back to the
  /// non-cooperative (script) path. The fee is recomputed per path via
  /// [feeFor]: the script path has a larger tx size, so it must be re-sized and
  /// re-capped rather than reusing the cooperative fee.
  Future<String> _withCoopFallback(
    Future<int> Function(bool cooperate) feeFor,
    Future<String> Function(bool cooperate, int fees) attempt,
  ) async {
    try {
      return await attempt(true, await feeFor(true));
    } catch (_) {
      return await attempt(false, await feeFor(false));
    }
  }

  @override
  Future<Result<String, SwapFailure>> refund(
    String swapId, {
    required SwapEnvironment environment,
  }) async {
    try {
      final swap = await _repository.getSwap(swapId: swapId);
      final address = await _resolveRefundAddress(swap);
      final network = _refundNetwork(swap.type);
      final isLiquid = network == SwapNetwork.liquid;
      final rate = await _feeRate(network, environment);
      final chainAddress = swap.type.isChain ? address : null;
      Future<int> refundFee(bool cooperate) async {
        final size = await _repository.getSwapRefundTxSize(
          swapId: swapId,
          swapType: swap.type,
          isCooperative: cooperate,
          refundAddressForChainSwaps: chainAddress,
        );
        return _cappedFees(
          (size * rate).ceil(),
          txSize: size,
          isLiquid: isLiquid,
          amountSat: _stakeSat(swap),
        );
      }

      Future<String> refundWith(
        bool cooperate,
        int fees,
      ) => switch (swap.type) {
        SwapType.bitcoinToLightning => _repository.refundBitcoinToLightningSwap(
          swapId: swapId,
          bitcoinAddress: address,
          absoluteFees: fees,
          cooperate: cooperate,
        ),
        SwapType.liquidToLightning => _repository.refundLiquidToLightningSwap(
          swapId: swapId,
          liquidAddress: address,
          absoluteFees: fees,
          cooperate: cooperate,
        ),
        SwapType.bitcoinToLiquid => _repository.refundBitcoinToLiquidSwap(
          swapId: swapId,
          bitcoinRefundAddress: address,
          absoluteFees: fees,
          cooperate: cooperate,
        ),
        SwapType.liquidToBitcoin => _repository.refundLiquidToBitcoinSwap(
          swapId: swapId,
          liquidRefundAddress: address,
          absoluteFees: fees,
          cooperate: cooperate,
        ),
        _ => throw const _NotRefundable(),
      };
      return Ok(await _withCoopFallback(refundFee, refundWith));
    } catch (error) {
      return Err(_map(error));
    }
  }

  String _requireWallet(String? walletId) {
    if (walletId == null) {
      throw const _MissingWallet();
    }
    return walletId;
  }

  SwapType _swapType(SwapNetwork inNetwork, SwapNetwork outNetwork) => switch ((
    inNetwork,
    outNetwork,
  )) {
    (SwapNetwork.bitcoin, SwapNetwork.lightning) => SwapType.bitcoinToLightning,
    (SwapNetwork.liquid, SwapNetwork.lightning) => SwapType.liquidToLightning,
    (SwapNetwork.lightning, SwapNetwork.bitcoin) => SwapType.lightningToBitcoin,
    (SwapNetwork.lightning, SwapNetwork.liquid) => SwapType.lightningToLiquid,
    (SwapNetwork.bitcoin, SwapNetwork.liquid) => SwapType.bitcoinToLiquid,
    (SwapNetwork.liquid, SwapNetwork.bitcoin) => SwapType.liquidToBitcoin,
    _ => throw const _UnsupportedRoute(),
  };

  SwapNetwork _claimNetwork(SwapType type) => switch (type) {
    SwapType.lightningToBitcoin ||
    SwapType.liquidToBitcoin => SwapNetwork.bitcoin,
    SwapType.lightningToLiquid ||
    SwapType.bitcoinToLiquid => SwapNetwork.liquid,
    _ => SwapNetwork.bitcoin,
  };

  SwapNetwork _refundNetwork(SwapType type) => switch (type) {
    SwapType.bitcoinToLightning ||
    SwapType.bitcoinToLiquid => SwapNetwork.bitcoin,
    SwapType.liquidToLightning ||
    SwapType.liquidToBitcoin => SwapNetwork.liquid,
    _ => SwapNetwork.bitcoin,
  };

  Future<String> _resolveClaimAddress(Swap swap) async {
    final (stored, walletId) = switch (swap) {
      LnReceiveSwap(:final receiveAddress, :final receiveWalletId) => (
        receiveAddress,
        receiveWalletId,
      ),
      ChainSwap(:final receiveAddress, :final receiveWalletId) => (
        receiveAddress,
        receiveWalletId,
      ),
      _ => (null, null),
    };
    if (stored != null) return _plainAddress(stored);
    if (walletId == null) throw const _MissingAddress();
    final generated = await _getReceiveAddress.execute(
      walletId: walletId,
      generateNew: true,
    );
    await _repository.updateSwapFields(
      swap.id,
      receiveAddress: generated.address,
    );
    return generated.address;
  }

  Future<String> _resolveRefundAddress(Swap swap) async {
    final (stored, walletId) = switch (swap) {
      LnSendSwap(:final refundAddress, :final sendWalletId) => (
        refundAddress,
        sendWalletId,
      ),
      ChainSwap(:final refundAddress, :final sendWalletId) => (
        refundAddress,
        sendWalletId,
      ),
      _ => (null, null),
    };
    if (stored != null) return _plainAddress(stored);
    if (walletId == null) throw const _MissingAddress();
    final generated = await _getReceiveAddress.execute(
      walletId: walletId,
      generateNew: true,
    );
    await _repository.updateSwapFields(
      swap.id,
      refundAddress: generated.address,
    );
    return generated.address;
  }

  String _plainAddress(String value) {
    if (value.startsWith('bitcoin:') ||
        value.startsWith('liquidnetwork:') ||
        value.startsWith('liquidtestnet:')) {
      return bip21.decode(value).address;
    }
    return value;
  }

  /// Live claim fee computed fresh at claim time from a current tx size and the
  /// live network fee rate, floored and capped. The stored creation-time
  /// estimate is used only as a last resort when live estimation fails
  /// entirely (e.g. a rescued swap whose cooperative sizing can't round-trip),
  /// never in preference to a fresh fee.
  Future<int> _claimFee(
    Swap swap,
    bool isLiquid,
    double rate,
    bool cooperate,
    String? chainAddress,
  ) async {
    try {
      final size = await _repository.getSwapClaimTxSize(
        swapId: swap.id,
        swapType: swap.type,
        isCooperative: cooperate,
        claimAddressForChainSwaps: chainAddress,
      );
      return _cappedFees(
        (size * rate).ceil(),
        txSize: size,
        isLiquid: isLiquid,
        amountSat: _stakeSat(swap),
      );
    } catch (_) {
      final stored = swap.fees?.claimFee;
      if (stored != null && stored > 0) return stored;
      rethrow;
    }
  }

  int? _stakeSat(Swap swap) => switch (swap) {
    LnSendSwap(:final paymentAmount) => paymentAmount,
    ChainSwap(:final paymentAmount) => paymentAmount,
    _ => null,
  };

  int _relayFloor({required int txSize, required bool isLiquid}) =>
      isLiquid ? (txSize * 0.11).ceil() + 1 : txSize;

  int _cappedFees(
    int absolute, {
    required int txSize,
    required bool isLiquid,
    required int? amountSat,
  }) {
    final floor = _relayFloor(txSize: txSize, isLiquid: isLiquid);
    final withFloor = max(absolute, floor);
    if (amountSat == null || amountSat <= 0) return withFloor;
    return max(floor, min(withFloor, max(1, amountSat ~/ 2)));
  }

  CreatedSwap _fromSend(
    LnSendSwap swap,
    SwapNetwork fromNetwork,
    SwapEnvironment environment,
  ) => CreatedSwap(
    providerId: 'boltz',
    swapId: swap.id,
    environment: environment,
    inNetwork: fromNetwork,
    outNetwork: SwapNetwork.lightning,
    payinAmountSat: BigInt.from(swap.paymentAmount),
    payoutAmountSat: BigInt.from(swap.paymentAmount),
    payinAddress: swap.paymentAddress,
  );

  CreatedSwap _fromReceive(
    LnReceiveSwap swap,
    SwapNetwork toNetwork,
    BigInt amountSat,
    SwapEnvironment environment,
  ) => CreatedSwap(
    providerId: 'boltz',
    swapId: swap.id,
    environment: environment,
    inNetwork: SwapNetwork.lightning,
    outNetwork: toNetwork,
    payinAmountSat: amountSat,
    payoutAmountSat: amountSat,
    payinInvoice: swap.invoice,
  );

  CreatedSwap _fromChain(
    ChainSwap swap,
    SwapNetwork fromNetwork,
    SwapNetwork toNetwork,
    SwapEnvironment environment,
  ) => CreatedSwap(
    providerId: 'boltz',
    swapId: swap.id,
    environment: environment,
    inNetwork: fromNetwork,
    outNetwork: toNetwork,
    payinAmountSat: BigInt.from(swap.paymentAmount),
    payoutAmountSat: BigInt.from(swap.paymentAmount),
    payinAddress: swap.paymentAddress,
  );

  SwapStatusUpdate _status(Swap swap) => SwapStatusUpdate(
    swapId: swap.id,
    status: switch (swap.status) {
      SwapStatus.pending => SwapLifecycleStatus.awaitingPayin,
      SwapStatus.paid => SwapLifecycleStatus.payinDetected,
      SwapStatus.claimable ||
      SwapStatus.canCoop => SwapLifecycleStatus.payoutInProgress,
      SwapStatus.refundable => SwapLifecycleStatus.failed,
      SwapStatus.completed => SwapLifecycleStatus.completed,
      SwapStatus.refunded => SwapLifecycleStatus.refunded,
      SwapStatus.expired => SwapLifecycleStatus.expired,
      SwapStatus.failed => SwapLifecycleStatus.failed,
    },
  );

  SwapFailure _map(Object error) => switch (error) {
    _MissingWallet() => const SwapValidationFailure(field: 'walletId'),
    _MissingAddress() => const SwapValidationFailure(field: 'address'),
    _UnsupportedRoute() => const SwapNoPaymentOptionFailure(),
    _NotClaimable() || _NotRefundable() => const SwapInvalidStateFailure(),
    _ => SwapUnexpectedFailure(error.toString()),
  };
}

class _MissingWallet implements Exception {
  const _MissingWallet();
}

class _MissingAddress implements Exception {
  const _MissingAddress();
}

class _UnsupportedRoute implements Exception {
  const _UnsupportedRoute();
}

class _NotClaimable implements Exception {
  const _NotClaimable();
}

class _NotRefundable implements Exception {
  const _NotRefundable();
}
