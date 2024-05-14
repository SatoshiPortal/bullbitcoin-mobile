import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/swap/bloc/swap_state.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapCubit extends Cubit<SwapState> {
  SwapCubit({
    required WalletSensitiveStorageRepository walletSensitiveRepository,
    required SwapBoltz swapBoltz,
    required WalletTx walletTx,
  })  : _walletTx = walletTx,
        _swapBoltz = swapBoltz,
        _walletSensitiveRepository = walletSensitiveRepository,
        super(const SwapState());

  final WalletSensitiveStorageRepository _walletSensitiveRepository;
  final SwapBoltz _swapBoltz;
  final WalletTx _walletTx;

  // void decodeInvoice(String invoice) async {
  //   final (inv, err) = await _swapBoltz.decodeInvoice(invoice: invoice);
  //   if (err != null) {
  //     emit(
  //       state.copyWith(
  //         errCreatingSwapInv: err.toString(),
  //         generatingSwapInv: false,
  //       ),
  //     );
  //     return;
  //   }
  //   emit(state.copyWith(invoice: inv));
  // }

  Future<void> fetchFees(bool isTestnet) async {
    final boltzurl = isTestnet ? boltzTestnet : boltzMainnet;

    final (fees, errFees) = await _swapBoltz.getFeesAndLimits(
      boltzUrl: boltzurl,
    );
    if (errFees != null) {
      emit(state.copyWith(errAllFees: errFees.toString()));
    }
    emit(state.copyWith(allFees: fees));
  }

  void createRevSwapForReceive({
    required Wallet wallet,
    required int amount,
    String? label,
    required bool isTestnet,
    required String networkUrl,
  }) async {
    // if (!isTestnet) return;

    emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));

    final boltzurl = isTestnet ? boltzTestnet : boltzMainnet;
    final boltzurlV2 = isTestnet ? boltzTestnetV2 : boltzMainnetV2;

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

    final walletIsLiquid = wallet.baseWalletType == BaseWalletType.Liquid;

    if (walletIsLiquid) {
      if (amount < fees!.lbtcLimits.minimal ||
          amount > fees.lbtcLimits.maximal) {
        emit(
          state.copyWith(
            errCreatingSwapInv:
                'Amount should be greater than ${fees.lbtcLimits.minimal} and less than ${fees.lbtcLimits.maximal} sats',
            generatingSwapInv: false,
          ),
        );
        return;
      }
    } else {
      if (amount < fees!.btcLimits.minimal || amount > fees.btcLimits.maximal) {
        emit(
          state.copyWith(
            errCreatingSwapInv:
                'Amount should be greater than ${fees.btcLimits.minimal} and less than ${fees.btcLimits.maximal} sats',
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
    final (swap, errCreatingInv) = await _swapBoltz.receiveV2(
      mnemonic: seed!.mnemonic,
      index: wallet.revKeyIndex,
      outAmount: amount,
      network: network,
      electrumUrl: networkUrl,
      boltzUrl: boltzurlV2,
      isLiquid: walletIsLiquid,
      claimAddress: claimAddress,
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

    final updatedSwap = swap!.copyWith(
      boltzFees: walletIsLiquid
          ? fees.lbtcReverse.boltzFeesRate * amount ~/ 100
          : fees.btcReverse.boltzFeesRate * amount ~/ 100,
      lockupFees: walletIsLiquid
          ? fees.lbtcReverse.lockupFees
          : fees.btcReverse.lockupFees,
      claimFees: walletIsLiquid
          ? fees.lbtcReverse.claimFeesEstimate
          : fees.btcReverse.claimFeesEstimate,
    );

    emit(
      state.copyWith(
        generatingSwapInv: false,
        errCreatingSwapInv: '',
        swapTx: updatedSwap,
      ),
    );

    _showWarnings();

    _saveSwapToWallet(
      swapTx: updatedSwap,
      label: label,
      wallet: wallet,
    );
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

  // Future createBtcLnSubSwap({
  //   required Wallet wallet,
  //   required String invoice,
  //   required int amount,
  //   String? label,
  //   required bool isTestnet,
  //   required String networkUrl,
  // }) async {
  //   emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));

  //   final (fees, errFees) = await _swapBoltz.getFeesAndLimits(
  //     boltzUrl: isTestnet ? boltzTestnet : boltzMainnet,
  //   );
  //   if (errFees != null) {
  //     emit(
  //       state.copyWith(
  //         errCreatingSwapInv: errFees.toString(),
  //         generatingSwapInv: false,
  //       ),
  //     );
  //     return;
  //   }

  //   final (seed, errReadingSeed) = await _walletSensitiveRepository.readSeed(
  //     fingerprintIndex: wallet.getRelatedSeedStorageString(),
  //   );
  //   if (errReadingSeed != null) {
  //     emit(
  //       state.copyWith(
  //         errCreatingSwapInv: errReadingSeed.toString(),
  //         generatingSwapInv: false,
  //       ),
  //     );
  //     return;
  //   }

  //   final (swap, err) = await _swapBoltz.sendV2(
  //     boltzUrl: isTestnet ? boltzTestnetV2 : boltzMainnetV2,
  //     mnemonic: seed!.mnemonic,
  //     index: wallet.revKeyIndex,
  //     invoice: invoice,
  //     network: isTestnet ? Chain.bitcoinTestnet : Chain.bitcoin,
  //     electrumUrl: networkUrl,
  //     isLiquid: false,
  //   );
  //   if (err != null) {
  //     emit(
  //       state.copyWith(
  //         errCreatingSwapInv: err.message,
  //         generatingSwapInv: false,
  //       ),
  //     );
  //     return;
  //   }

  //   final updatedSwap = swap!.copyWith(
  //     boltzFees: (fees!.btcReverse.boltzFeesRate * amount / 100) as int,
  //     lockupFees: fees.btcReverse.lockupFees,
  //     claimFees: fees.btcReverse.claimFeesEstimate,
  //   );

  //   emit(
  //     state.copyWith(
  //       generatingSwapInv: false,
  //       errCreatingSwapInv: '',
  //       swapTx: updatedSwap,
  //     ),
  //   );

  //   await _saveSwapToWallet(
  //     swapTx: updatedSwap,
  //     wallet: wallet,
  //     label: label,
  //   );
  // }

  Future createSubSwapForSend({
    required Wallet wallet,
    required String invoice,
    required int amount,
    String? label,
    required bool isTestnet,
    required String networkUrl,
  }) async {
    emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));

    final boltzurl = isTestnet ? boltzTestnet : boltzMainnet;
    final boltzurlV2 = isTestnet ? boltzTestnetV2 : boltzMainnetV2;

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
    if (isLiq) {
      if (amount < fees!.lbtcLimits.minimal ||
          amount > fees.lbtcLimits.maximal) {
        emit(
          state.copyWith(
            errCreatingSwapInv:
                'Amount should be greater than ${fees.lbtcLimits.minimal} and less than ${fees.lbtcLimits.maximal} sats',
            generatingSwapInv: false,
          ),
        );
        return;
      }
    } else {
      if (amount < fees!.btcLimits.minimal || amount > fees.btcLimits.maximal) {
        emit(
          state.copyWith(
            errCreatingSwapInv:
                'Amount should be greater than ${fees.btcLimits.minimal} and less than ${fees.btcLimits.maximal} sats',
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

    final (swap, errCreatingInv) = await _swapBoltz.sendV2(
      mnemonic: seed!.mnemonic,
      index: wallet.revKeyIndex,
      network: network,
      electrumUrl: networkUrl,
      boltzUrl: boltzurlV2,
      isLiquid: isLiq,
      invoice: invoice,
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

    final updatedSwap = swap!.copyWith(
      boltzFees: isLiq
          ? fees.lbtcSubmarine.boltzFeesRate * amount ~/ 100
          : fees.btcSubmarine.boltzFeesRate * amount ~/ 100,
      lockupFees: isLiq
          ? fees.lbtcSubmarine.lockupFeesEstimate
          : fees.btcSubmarine.lockupFeesEstimate,
      claimFees:
          isLiq ? fees.lbtcSubmarine.claimFees : fees.btcSubmarine.claimFees,
    );

    emit(
      state.copyWith(
        generatingSwapInv: false,
        errCreatingSwapInv: '',
        swapTx: updatedSwap,
      ),
    );

    _showWarnings();

    _saveSwapToWallet(
      swapTx: updatedSwap,
      label: label,
      wallet: wallet,
    );
  }

  Future _saveSwapToWallet({
    required Wallet wallet,
    required SwapTx swapTx,
    String? label,
  }) async {
    final (updatedWallet, err) = await _walletTx.addSwapTxToWallet(
      wallet: wallet.copyWith(
        revKeyIndex:
            !swapTx.isSubmarine ? wallet.revKeyIndex + 1 : wallet.revKeyIndex,
        subKeyIndex:
            swapTx.isSubmarine ? wallet.subKeyIndex + 1 : wallet.subKeyIndex,
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

    // await Future.delayed(const Duration(seconds: 5));
    print('-----swap added to wallet ${swapTx.id}');
    emit(state.copyWith(updatedWallet: updatedWallet));
  }

  void clearSwapTx() => emit(state.copyWith(swapTx: null));

  void clearUpdatedWallet() => emit(state.copyWith(updatedWallet: null));

  void clearErrors() => emit(
        state.copyWith(
          errCreatingSwapInv: '',
          errCreatingInvoice: '',
        ),
      );
}
