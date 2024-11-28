import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_state.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_event.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateSwapCubit extends Cubit<SwapState> {
  CreateSwapCubit({
    required WalletSensitiveStorageRepository walletSensitiveRepository,
    required SwapBoltz swapBoltz,
    required WalletTx walletTx,
    required HomeCubit homeCubit,
    required WatchTxsBloc watchTxsBloc,
    required NetworkCubit networkCubit,
  })  : _walletTx = walletTx,
        _swapBoltz = swapBoltz,
        _homeCubit = homeCubit,
        _watchTxsBloc = watchTxsBloc,
        _walletSensitiveRepository = walletSensitiveRepository,
        _networkCubit = networkCubit,
        super(const SwapState());

  final WalletSensitiveStorageRepository _walletSensitiveRepository;
  final SwapBoltz _swapBoltz;
  final WalletTx _walletTx;
  final HomeCubit _homeCubit;
  final WatchTxsBloc _watchTxsBloc;
  final NetworkCubit _networkCubit;
  Future<void> fetchFees(bool isTestnet) async {
    final boltzurl = isTestnet ? boltzTestnetUrl : boltzMainnetUrl;

    final (fees, errFees) = await _swapBoltz.getFeesAndLimits(
      boltzUrl: boltzurl,
    );
    if (errFees != null) {
      emit(state.copyWith(errAllFees: errFees.toString()));
    }

    final submarineFees = await fees?.submarine();
    final reverseFees = await fees?.reverse();

    emit(
      state.copyWith(submarineFees: submarineFees, reverseFees: reverseFees),
    );
  }

  Future<void> createRevSwapForReceive({
    required Wallet wallet,
    required int amount,
    String? label,
    required bool isTestnet,
    required String networkUrl,
  }) async {
    // if (!isTestnet) return;

    emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));

    final boltzurl = isTestnet ? boltzTestnetUrl : boltzMainnetUrl;

    // we dont have to make this call here
    // we have fees stored which has a pairHash
    // we use the pairHash when creating a swap
    // if the swap creation fails because of the pairHash, its because the fees updated and we can recall fetchFees
    // an optimization for later
    final (fees, errFees) = await _swapBoltz.getFeesAndLimits(
      boltzUrl: boltzurl,
    );
    if (errFees != null) {
      emit(
        state.copyWith(
          errCreatingSwapInv: errFees.toString(),
          generatingSwapInv: false,
        ),
      );
      return;
    }

    final walletIsLiquid = wallet.isLiquid();

    final reverseFees = await fees?.reverse();

    if (reverseFees == null) {
      emit(
        state.copyWith(
          errCreatingSwapInv: 'Reverse fees not found',
          generatingSwapInv: false,
        ),
      );
      return;
    }

    if (walletIsLiquid) {
      if (amount < reverseFees.lbtcLimits.minimal.toInt() ||
          amount > reverseFees.lbtcLimits.maximal.toInt()) {
        emit(
          state.copyWith(
            errCreatingSwapInv:
                'Amount should be greater than ${reverseFees.lbtcLimits.minimal} and less than ${reverseFees.lbtcLimits.maximal} sats',
            generatingSwapInv: false,
          ),
        );
        return;
      }
    } else {
      if (amount < reverseFees.btcLimits.minimal.toInt() ||
          amount > reverseFees.btcLimits.maximal.toInt()) {
        emit(
          state.copyWith(
            errCreatingSwapInv:
                'Amount should be greater than ${reverseFees.btcLimits.minimal} and less than ${reverseFees.btcLimits.maximal} sats',
            generatingSwapInv: false,
          ),
        );
        return;
      }
    }

    final (seed, errReadingSeed) = await _walletSensitiveRepository.readSeed(
      fingerprintIndex: wallet.getRelatedSeedStorageString(),
    );
    if (errReadingSeed != null) {
      emit(
        state.copyWith(
          errCreatingSwapInv: errReadingSeed.toString(),
          generatingSwapInv: false,
        ),
      );
      return;
    }
    final network = isTestnet
        ? (walletIsLiquid ? Chain.liquidTestnet : Chain.bitcoinTestnet)
        : (walletIsLiquid ? Chain.liquid : Chain.bitcoin);

    final claimAddress = wallet.lastGeneratedAddress!.address;
    final (swap, errCreatingInv) = await _swapBoltz.receive(
      mnemonic: seed!.mnemonic,
      index: wallet.revKeyIndex,
      outAmount: amount,
      network: network,
      electrumUrl: networkUrl,
      boltzUrl: boltzurl,
      isLiquid: walletIsLiquid,
      claimAddress: claimAddress,
      description: label,
    );
    if (errCreatingInv != null) {
      emit(
        state.copyWith(
          errCreatingSwapInv: errCreatingInv.toString(),
          generatingSwapInv: false,
        ),
      );
      return;
    }

    // final updatedSwap = swap!.copyWith(
    //   boltzFees: walletIsLiquid
    //       ? fees.lbtcReverse.boltzFeesRate * amount ~/ 100
    //       : fees.btcReverse.boltzFeesRate * amount ~/ 100,
    //   lockupFees: walletIsLiquid
    //       ? fees.lbtcReverse.lockupFees
    //       : fees.btcReverse.lockupFees,
    //   claimFees: walletIsLiquid
    //       ? fees.lbtcReverse.claimFeesEstimate
    //       : fees.btcReverse.claimFeesEstimate,
    // );

    /*
    final updatedSwap = swap!.copyWith(
      boltzFees: walletIsLiquid
          ? fees.lbtcReverse.boltzFeesRate * amount ~/ 100
          : fees.btcReverse.boltzFeesRate * amount ~/ 100,
      lockupFees: walletIsLiquid
          ? fees.lbtcReverse.lockupFees
          : fees.btcReverse.lockupFees,
      claimFees: walletIsLiquid
          ? liquidElectrum == LiquidElectrumTypes.bullbitcoin
              ? fees.lbtcReverse.claimFeesEstimate
              : fees.lbtcReverse.claimFeesEstimate
          : fees.btcReverse.claimFeesEstimate,
      label: label,
    );
    */
    final updatedSwap = swap!.copyWith(
      boltzFees: walletIsLiquid
          ? reverseFees.lbtcFees.percentage * amount ~/ 100
          : reverseFees.lbtcFees.percentage * amount ~/ 100,
      lockupFees: (walletIsLiquid
              ? reverseFees.lbtcFees.minerFees.lockup
              : reverseFees.btcFees.minerFees.lockup)
          .toInt(),
      claimFees: (walletIsLiquid
              ? reverseFees.lbtcFees.minerFees.claim
              : reverseFees.btcFees.minerFees.claim)
          .toInt(),
      label: label,
    );

    await saveSwapToWallet(
      swapTx: updatedSwap,
      wallet: wallet,
    );

    // await Future.delayed(800.ms);

    emit(
      state.copyWith(
        generatingSwapInv: false,
        errCreatingSwapInv: '',
        swapTx: updatedSwap,
      ),
    );

    _showWarnings();
  }

  void _showWarnings() {
    final swapTx = state.swapTx;
    if (swapTx == null) return;
    emit(
      state.copyWith(
        errSmallAmt: swapTx.smallAmt(),
        errHighFees: swapTx.highFees(),
      ),
    );
  }

  void removeWarnings() =>
      emit(state.copyWith(errSmallAmt: false, errHighFees: null));

  Future createSubSwapForSend({
    required Wallet wallet,
    required String address,
    required int amount,
    String? label,
    required bool isTestnet,
    required String networkUrl,
    required Invoice invoice,
  }) async {
    try {
      emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));

      final boltzurl = isTestnet ? boltzTestnetUrl : boltzMainnetUrl;

      // we dont have to make this call here
      // we have fees stored which has a pairHash
      // we use the pairHash when creating a swap
      // if the swap creation fails because of the pairHash, its because the fees updated and we can recall fetchFees
      // an optimization for later
      final (fees, errFees) = await _swapBoltz.getFeesAndLimits(
        boltzUrl: boltzurl,
      );
      if (errFees != null) {
        emit(
          state.copyWith(
            errCreatingSwapInv: errFees.toString(),
            generatingSwapInv: false,
          ),
        );
        return;
      }

      final isLiq = wallet.isLiquid();
      final submarineFees = await fees?.submarine();
      if (submarineFees == null) {
        emit(
          state.copyWith(
            errCreatingSwapInv: 'Submarine fees not found',
            generatingSwapInv: false,
          ),
        );
        return;
      }

      if (isLiq) {
        if (amount < submarineFees.lbtcLimits.minimal.toInt() ||
            amount > submarineFees.lbtcLimits.maximal.toInt()) {
          emit(
            state.copyWith(
              errCreatingSwapInv:
                  'Amount should be greater than ${submarineFees.lbtcLimits.minimal} and less than ${submarineFees.lbtcLimits.maximal} sats',
              generatingSwapInv: false,
            ),
          );
          return;
        }
      } else {
        if (amount < submarineFees.btcLimits.minimal.toInt() ||
            amount > submarineFees.btcLimits.maximal.toInt()) {
          emit(
            state.copyWith(
              errCreatingSwapInv:
                  'Amount should be greater than ${submarineFees.btcLimits.minimal} and less than ${submarineFees.btcLimits.maximal} sats',
              generatingSwapInv: false,
            ),
          );
          return;
        }
      }

      final (seed, errReadingSeed) = await _walletSensitiveRepository.readSeed(
        fingerprintIndex: wallet.getRelatedSeedStorageString(),
      );
      if (errReadingSeed != null) {
        emit(
          state.copyWith(
            errCreatingSwapInv: errReadingSeed.toString(),
            generatingSwapInv: false,
          ),
        );
        return;
      }
      final network = isTestnet
          ? (isLiq ? Chain.liquidTestnet : Chain.bitcoinTestnet)
          : (isLiq ? Chain.liquid : Chain.bitcoin);

      final storedSwapTxIdx = wallet.swaps.indexWhere(
        (e) =>
            e.lnSwapDetails != null &&
            e.lnSwapDetails!.invoice == invoice.invoice,
      );

      SwapTx swapTx;
      if (storedSwapTxIdx != -1) {
        swapTx = wallet.swaps[storedSwapTxIdx];
      } else {
        final (swap, errCreatingInv) = await _swapBoltz.send(
          mnemonic: seed!.mnemonic,
          index: wallet.revKeyIndex,
          network: network,
          electrumUrl: networkUrl,
          boltzUrl: boltzurl,
          isLiquid: isLiq,
          invoice: address,
        );
        if (errCreatingInv != null) {
          emit(
            state.copyWith(
              errCreatingSwapInv: errCreatingInv.toString(),
              generatingSwapInv: false,
            ),
          );
          return;
        }

        //final updatedSwap = swap!.copyWith(
        //  boltzFees: isLiq
        //      ? fees.lbtcSubmarine.boltzFeesRate * amount ~/ 100
        //      : fees.btcSubmarine.boltzFeesRate * amount ~/ 100,
        //  lockupFees: isLiq
        //      ? fees.lbtcSubmarine.lockupFeesEstimate
        //      : fees.btcSubmarine.lockupFeesEstimate,
        //  claimFees:
        //      isLiq ? fees.lbtcSubmarine.claimFees : fees.btcSubmarine.claimFees,
        //  label: label,
        //);

        // TODO: Test this properly
        final updatedSwap = swap!.copyWith(
          boltzFees: isLiq
              ? submarineFees.lbtcFees.percentage * amount ~/ 100
              : submarineFees.btcFees.percentage * amount ~/ 100,
          lockupFees: (isLiq
                  ? submarineFees.lbtcFees.minerFees
                  : submarineFees.btcFees.minerFees)
              .toInt(),
          claimFees: (isLiq
                  ? submarineFees.lbtcFees.minerFees
                  : submarineFees.btcFees.minerFees)
              .toInt(),
          label: label,
        );

        swapTx = updatedSwap;

        await saveSwapToWallet(
          swapTx: swapTx,
          wallet: wallet,
        );

        // await Future.delayed(300.ms);
      }

      emit(
        state.copyWith(
          generatingSwapInv: false,
          errCreatingSwapInv: '',
          swapTx: swapTx,
        ),
      );

      _showWarnings();
    } catch (e) {
      print(e);
    }
  }

  Future saveSwapToWallet({
    required Wallet wallet,
    required SwapTx swapTx,
  }) async {
    final isSend =
        swapTx.isSubmarine() || swapTx.isChainSend() || swapTx.isChainSelf();
    final isReceive = swapTx.isReverse() || swapTx.isChainReceive();
    final (updatedWallet, err) = await _walletTx.addSwapTxToWallet(
      wallet: wallet.copyWith(
        revKeyIndex: isReceive ? wallet.revKeyIndex + 1 : wallet.revKeyIndex,
        subKeyIndex: isSend ? wallet.subKeyIndex + 1 : wallet.subKeyIndex,
      ),
      swapTx: swapTx,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errCreatingSwapInv: err.toString(),
          generatingSwapInv: false,
        ),
      );
      return;
    }

    _homeCubit.state.getWalletBloc(updatedWallet)?.add(
          UpdateWallet(
            updatedWallet,
            updateTypes: [
              UpdateWalletTypes.swaps,
              UpdateWalletTypes.transactions,
            ],
          ),
        );

    await Future.delayed(const Duration(milliseconds: 300));

    _watchTxsBloc.add(
      WatchWallets(),
    );

    await Future.delayed(const Duration(milliseconds: 300));

    //     context
    //         .read<WatchTxsBloc>()
    //         .add(WatchWallets(isTestnet: isTestnet));

    // emit(state.copyWith(updatedWallet: updatedWallet));
  }

  void setSwapTx(SwapTx swapTx) => emit(state.copyWith(swapTx: swapTx));

  void clearSwapTx() => emit(state.copyWith(swapTx: null));

  void clearErrors() => emit(
        state.copyWith(
          errCreatingSwapInv: '',
          // errCreatingInvoice: '',
        ),
      );

  void setValidationError(String validationMsg) =>
      emit(state.copyWith(errCreatingSwapInv: validationMsg));

  Future<void> createOnChainSwap({
    required Wallet wallet,
    required int amount,
    bool sweep = false,
    String? label,
    required bool isTestnet,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    required String toAddress,
    required String refundAddress,
    required ChainSwapDirection direction,
    required String toWalletId,
    required OnChainSwapType onChainSwapType,
  }) async {
    try {
      emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));

      final boltzurl = isTestnet ? boltzTestnetUrl : boltzMainnetUrl;

      // we dont have to make this call here
      // we have fees stored which has a pairHash
      // we use the pairHash when creating a swap
      // if the swap creation fails because of the pairHash, its because the fees updated and we can recall fetchFees
      // an optimization for later
      final (fees, errFees) = await _swapBoltz.getFeesAndLimits(
        boltzUrl: boltzurl,
      );
      if (errFees != null) {
        emit(
          state.copyWith(
            errCreatingSwapInv: errFees.toString(),
            generatingSwapInv: false,
          ),
        );
        return;
      }

      final isFromWalletLiq = wallet.isLiquid();
      final chainFees = await fees?.chain();
      if (chainFees == null) {
        emit(
          state.copyWith(
            errCreatingSwapInv: 'Chain fees not found',
            generatingSwapInv: false,
          ),
        );
        return;
      }

      if (isFromWalletLiq) {
        if (amount < chainFees.lbtcLimits.minimal.toInt() ||
            amount > chainFees.lbtcLimits.maximal.toInt()) {
          emit(
            state.copyWith(
              errCreatingSwapInv:
                  'Amount should be greater than ${chainFees.lbtcLimits.minimal} and less than ${chainFees.lbtcLimits.maximal} sats',
              generatingSwapInv: false,
            ),
          );
          return;
        }
      } else {
        if (amount < chainFees.btcLimits.minimal.toInt() ||
            amount > chainFees.btcLimits.maximal.toInt()) {
          emit(
            state.copyWith(
              errCreatingSwapInv:
                  'Amount should be greater than ${chainFees.btcLimits.minimal} and less than ${chainFees.btcLimits.maximal} sats',
              generatingSwapInv: false,
            ),
          );
          return;
        }
      }

      final (seed, errReadingSeed) = await _walletSensitiveRepository.readSeed(
        fingerprintIndex: wallet.getRelatedSeedStorageString(),
      );
      if (errReadingSeed != null) {
        emit(
          state.copyWith(
            errCreatingSwapInv: errReadingSeed.toString(),
            generatingSwapInv: false,
          ),
        );
        return;
      }
      final network = isTestnet
          ? (isFromWalletLiq ? Chain.liquidTestnet : Chain.bitcoinTestnet)
          : (isFromWalletLiq ? Chain.liquid : Chain.bitcoin);

      /*
      final storedSwapTxIdx = wallet.swaps.indexWhere(
        (_) => _.chainSwapDetails. == ,
      );
      */

      SwapTx swapTx;
      // if (storedSwapTxIdx != -1) {
      //   swapTx = wallet.swaps[storedSwapTxIdx];
      // } else {
      final (swap, errCreatingInv) = await _swapBoltz.chainSwap(
        mnemonic: seed!.mnemonic,
        index: wallet.revKeyIndex,
        network: network,
        btcElectrumUrl: btcElectrumUrl, // 'electrum.blockstream.info:60002',
        lbtcElectrumUrl: lbtcElectrumUrl, // 'blockstream.info:465',
        boltzUrl: boltzurl,
        // isLiquid: isFromWalletLiq,
        direction: direction,
        amount: amount,
        toWalletId: toWalletId,
        onChainSwapType: onChainSwapType,
      );
      if (errCreatingInv != null) {
        emit(
          state.copyWith(
            errCreatingSwapInv: errCreatingInv.toString(),
            generatingSwapInv: false,
          ),
        );
        return;
      }

      // TODO:Onchain Test this properly
      final updatedSwap = swap!.copyWith(
        boltzFees: isFromWalletLiq
            ? (chainFees.btcFees.percentage * amount ~/ 100) +
                chainFees.btcFees.server.toInt()
            : (chainFees.lbtcFees.percentage * amount ~/ 100) +
                chainFees.lbtcFees.server.toInt(),
        lockupFees:
            0, // This is set to 0, since lockup fee is calculated in send tx //  isFromWalletLiq
        // ? chainFees.btcFees.userLockup
        // : chainFees.lbtcFees.userLockup,
        claimFees: (isFromWalletLiq
                ? chainFees.btcFees.userClaim
                : chainFees.lbtcFees.userClaim)
            .toInt(),
        label: label,
      );

      swapTx = updatedSwap.copyWith(
        claimAddress: toAddress,
        refundAddress: refundAddress,
      );

      await saveSwapToWallet(
        swapTx: swapTx,
        wallet: wallet,
      );

      emit(
        state.copyWith(
          generatingSwapInv: false,
          errCreatingSwapInv: '',
          swapTx: swapTx,
        ),
      );

      _showWarnings();
    } catch (e) {
      print(e);
    }
  }

  Future<void> createOnChainSwapForReceive({
    required Wallet toWallet,
    required int amount,
    bool sweep = false,
    String? label,
    // required String toAddress,
    required String refundAddress,
    required ChainSwapDirection direction,
  }) async {
    try {
      emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));

      final isTestnet = _networkCubit.state.testnet;
      final lbtcElectrumUrl = _networkCubit.state.getLiquidNetworkUrl();
      final btcNetworkUrl = _networkCubit.state.getNetworkUrl();
      final btcElectrumUrl = btcNetworkUrl.startsWith('ssl://')
          ? btcNetworkUrl.split('//')[1]
          : btcNetworkUrl;

      final toAddress = toWallet.lastGeneratedAddress?.address ?? '';

      final boltzurl = isTestnet ? boltzTestnetUrl : boltzMainnetUrl;

      // we dont have to make this call here
      // we have fees stored which has a pairHash
      // we use the pairHash when creating a swap
      // if the swap creation fails because of the pairHash, its because the fees updated and we can recall fetchFees
      // an optimization for later
      final (fees, errFees) = await _swapBoltz.getFeesAndLimits(
        boltzUrl: boltzurl,
      );
      if (errFees != null) {
        emit(
          state.copyWith(
            errCreatingSwapInv: errFees.toString(),
            generatingSwapInv: false,
          ),
        );
        return;
      }

      final isToWalletLiq = toWallet.isLiquid();
      final chainFees = await fees?.chain();
      if (chainFees == null) {
        emit(
          state.copyWith(
            errCreatingSwapInv: 'Chain fees not found',
            generatingSwapInv: false,
          ),
        );
        return;
      }

      if (isToWalletLiq) {
        if (amount < chainFees.btcLimits.minimal.toInt() ||
            amount > chainFees.btcLimits.maximal.toInt()) {
          emit(
            state.copyWith(
              errCreatingSwapInv:
                  'Amount should be greater than ${chainFees.btcLimits.minimal} and less than ${chainFees.btcLimits.maximal} sats',
              generatingSwapInv: false,
            ),
          );
          return;
        }
      } else {
        if (amount < chainFees.lbtcLimits.minimal.toInt() ||
            amount > chainFees.lbtcLimits.maximal.toInt()) {
          emit(
            state.copyWith(
              errCreatingSwapInv:
                  'Amount should be greater than ${chainFees.lbtcLimits.minimal} and less than ${chainFees.lbtcLimits.maximal} sats',
              generatingSwapInv: false,
            ),
          );
          return;
        }
      }

      final (seed, errReadingSeed) = await _walletSensitiveRepository.readSeed(
        fingerprintIndex: toWallet.getRelatedSeedStorageString(),
      );
      if (errReadingSeed != null) {
        emit(
          state.copyWith(
            errCreatingSwapInv: errReadingSeed.toString(),
            generatingSwapInv: false,
          ),
        );
        return;
      }
      final network = isTestnet
          ? (isToWalletLiq ? Chain.bitcoinTestnet : Chain.liquidTestnet)
          : (isToWalletLiq ? Chain.bitcoin : Chain.liquid);

      /*
      final storedSwapTxIdx = wallet.swaps.indexWhere(
        (_) => _.chainSwapDetails. == ,
      );
      */

      SwapTx swapTx;
      // if (storedSwapTxIdx != -1) {
      //   swapTx = wallet.swaps[storedSwapTxIdx];
      // } else {
      final (swap, errCreatingInv) = await _swapBoltz.chainSwap(
        mnemonic: seed!.mnemonic,
        index: toWallet.revKeyIndex,
        network: network,
        btcElectrumUrl: btcElectrumUrl, // 'electrum.blockstream.info:60002',
        lbtcElectrumUrl: lbtcElectrumUrl, // 'blockstream.info:465',
        boltzUrl: boltzurl,
        // isLiquid: !isToWalletLiq,
        direction: direction,
        amount: amount,
        toWalletId: toWallet.id,
        onChainSwapType: OnChainSwapType.receiveSwap,
      );
      if (errCreatingInv != null) {
        emit(
          state.copyWith(
            errCreatingSwapInv: errCreatingInv.toString(),
            generatingSwapInv: false,
          ),
        );
        return;
      }

      // TODO:Onchain Test this properly
      final updatedSwap = swap!.copyWith(
        boltzFees: isToWalletLiq
            ? (chainFees.btcFees.percentage * amount ~/ 100) +
                chainFees.btcFees.server.toInt()
            : (chainFees.lbtcFees.percentage * amount ~/ 100) +
                chainFees.lbtcFees.server.toInt(),
        lockupFees:
            0, // This is set to 0, since lockup fee is calculated in send tx //  isFromWalletLiq
        // ? chainFees.btcFees.userLockup
        // : chainFees.lbtcFees.userLockup,
        claimFees: (isToWalletLiq
                ? chainFees.lbtcFees.userClaim
                : chainFees.btcFees.userClaim)
            .toInt(),
        label: label,
      );

      swapTx = updatedSwap.copyWith(
        claimAddress: toAddress,
        refundAddress: refundAddress,
      );

      await saveSwapToWallet(
        swapTx: swapTx,
        wallet: toWallet,
      );

      emit(
        state.copyWith(
          generatingSwapInv: false,
          errCreatingSwapInv: '',
          swapTx: swapTx,
        ),
      );

      _showWarnings();
    } catch (e) {
      print(e);
    }
  }
}
