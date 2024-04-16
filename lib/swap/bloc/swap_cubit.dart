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

  void decodeInvoice(String invoice) async {
    final (inv, err) = await _swapBoltz.decodeInvoice(invoice: invoice);
    if (err != null) {
      emit(state.copyWith(errCreatingSwapInv: err.toString(), generatingSwapInv: false));
      return;
    }
    emit(state.copyWith(invoice: inv));
  }

  void createBtcLnRevSwap({
    required Wallet wallet,
    required int amount,
    String? label,
    required bool isTestnet,
    required String networkUrl,
  }) async {
    if (!isTestnet) return;

    final outAmount = amount;
    final (fees, errFees) = await _swapBoltz.getFeesAndLimits(
      boltzUrl: boltzTestnet,
      outAmount: outAmount,
    );
    if (errFees != null) {
      emit(state.copyWith(errCreatingSwapInv: errFees.toString(), generatingSwapInv: false));
      return;
    }

    if (outAmount < fees!.btcLimits.minimal || outAmount > fees.btcLimits.maximal) {
      emit(
        state.copyWith(
          errCreatingSwapInv: 'Amount should be greater than 50000 and less than 25000000 sats',
          generatingSwapInv: false,
        ),
      );
      return;
    }

    emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));
    final (seed, errReadingSeed) = await _walletSensitiveRepository.readSeed(
      fingerprintIndex: wallet.getRelatedSeedStorageString(),
    );
    if (errReadingSeed != null) {
      emit(state.copyWith(errCreatingSwapInv: errReadingSeed.toString(), generatingSwapInv: false));
      return;
    }

    final (swap, errCreatingInv) = await _swapBoltz.receive(
      mnemonic: seed!.mnemonic,
      index: wallet.revKeyIndex,
      outAmount: outAmount,
      network: isTestnet ? Chain.BitcoinTestnet : Chain.Bitcoin,
      electrumUrl: networkUrl,
      boltzUrl: boltzTestnet,
      pairHash: fees.btcPairHash,
    );
    if (errCreatingInv != null) {
      emit(state.copyWith(errCreatingSwapInv: errCreatingInv.toString(), generatingSwapInv: false));
      return;
    }

    final updatedSwap = swap!.copyWith(
      boltzFees: fees.btcReverse.boltzFees,
      lockupFees: fees.btcReverse.lockupFees,
      claimFees: fees.btcReverse.claimFeesEstimate,
    );

    emit(
      state.copyWith(
        generatingSwapInv: false,
        errCreatingSwapInv: '',
        swapTx: updatedSwap,
      ),
    );

    _showWarnings();

    _saveBtcLnSwapToWallet(
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

  void removeWarnings() => emit(state.copyWith(errSmallAmt: false, errHighFees: null));

  Future createBtcLnSubSwap({
    required Wallet wallet,
    required String invoice,
    required int amount,
    String? label,
    required bool isTestnet,
    required String networkUrl,
  }) async {
    emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));

    final (fees, errFees) = await _swapBoltz.getFeesAndLimits(
      boltzUrl: boltzTestnet,
      outAmount: amount,
    );
    if (errFees != null) {
      emit(state.copyWith(errCreatingSwapInv: errFees.toString(), generatingSwapInv: false));
      return;
    }

    final (seed, errReadingSeed) = await _walletSensitiveRepository.readSeed(
      fingerprintIndex: wallet.getRelatedSeedStorageString(),
    );
    if (errReadingSeed != null) {
      emit(state.copyWith(errCreatingSwapInv: errReadingSeed.toString(), generatingSwapInv: false));
      return;
    }

    final (swap, err) = await _swapBoltz.send(
      boltzUrl: boltzTestnet,
      pairHash: fees!.btcPairHash,
      mnemonic: seed!.mnemonic,
      index: wallet.revKeyIndex,
      invoice: invoice,
      network: isTestnet ? Chain.BitcoinTestnet : Chain.Bitcoin,
      electrumUrl: networkUrl,
    );
    if (err != null) {
      emit(state.copyWith(errCreatingSwapInv: err.message, generatingSwapInv: false));
      return;
    }

    final updatedSwap = swap!.copyWith(
      boltzFees: fees.btcSubmarine.boltzFees,
      lockupFees: fees.btcSubmarine.lockupFeesEstimate,
      claimFees: fees.btcSubmarine.claimFees,
    );

    emit(
      state.copyWith(
        generatingSwapInv: false,
        errCreatingSwapInv: '',
        swapTx: updatedSwap,
      ),
    );

    await _saveBtcLnSwapToWallet(
      swapTx: updatedSwap,
      wallet: wallet,
      label: label,
    );
  }

  Future _saveBtcLnSwapToWallet({
    required Wallet wallet,
    required SwapTx swapTx,
    String? label,
  }) async {
    final (updatedWallet, err) = await _walletTx.addSwapTxToWallet(
      wallet: wallet.copyWith(
        revKeyIndex: !swapTx.isSubmarine ? wallet.revKeyIndex + 1 : wallet.revKeyIndex,
        subKeyIndex: swapTx.isSubmarine ? wallet.subKeyIndex + 1 : wallet.subKeyIndex,
      ),
      swapTx: swapTx,
    );
    if (err != null) {
      emit(state.copyWith(errCreatingSwapInv: err.toString(), generatingSwapInv: false));
      return;
    }

    await Future.delayed(const Duration(seconds: 5));

    emit(state.copyWith(updatedWallet: updatedWallet));
  }

  void clearSwapTx() => emit(state.copyWith(swapTx: null));

  void clearWallet() => emit(state.copyWith(updatedWallet: null));
}
