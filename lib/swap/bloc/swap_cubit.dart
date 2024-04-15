import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_state.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_event.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapCubit extends Cubit<SwapState> {
  SwapCubit({
    required WalletSensitiveStorageRepository walletSensitiveRepository,
    // required this.settingsCubit,
    // required NetworkCubit networkCubit,
    required SwapBoltz swapBoltz,
    required WalletTx walletTx,
    required WatchTxsBloc watchTxsBloc,
    required HomeCubit homeCubit,
  })  : _homeCubit = homeCubit,
        _watchTxsBloc = watchTxsBloc,
        _walletTx = walletTx,
        _swapBoltz = swapBoltz,
        // _networkCubit = networkCubit,
        _walletSensitiveRepository = walletSensitiveRepository,
        super(const SwapState()) {
    // clearSwapTx();
  }

  final WalletSensitiveStorageRepository _walletSensitiveRepository;
  final SwapBoltz _swapBoltz;
  final WalletTx _walletTx;

  // final NetworkCubit _networkCubit;
  final WatchTxsBloc _watchTxsBloc;
  final HomeCubit _homeCubit;

  void decodeInvoice(String invoice) async {
    final (inv, err) = await _swapBoltz.decodeInvoice(invoice: invoice);
    if (err != null) {
      emit(state.copyWith(errCreatingSwapInv: err.toString(), generatingSwapInv: false));
      return;
    }
    emit(state.copyWith(invoice: inv));
  }

  void createBtcLnRevSwap({
    required String walletId,
    required int amount,
    String? label,
    required bool isTestnet,
    required String networkUrl,
  }) async {
    // if (!_networkCubit.state.testnet) return;
    if (!isTestnet) return;

    final bloc = _homeCubit.state.getWalletBlocById(walletId);
    if (bloc == null) return;

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
      fingerprintIndex: bloc.state.wallet!.getRelatedSeedStorageString(),
    );
    if (errReadingSeed != null) {
      emit(state.copyWith(errCreatingSwapInv: errReadingSeed.toString(), generatingSwapInv: false));
      return;
    }

    final (swap, errCreatingInv) = await _swapBoltz.receive(
      mnemonic: seed!.mnemonic,
      index: bloc.state.wallet!.revKeyIndex,
      outAmount: outAmount,
      // network: _networkCubit.state.testnet ? Chain.BitcoinTestnet : Chain.Bitcoin,
      network: isTestnet ? Chain.BitcoinTestnet : Chain.Bitcoin,
      // electrumUrl: _networkCubit.state.getNetworkUrl(),
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

    _saveBtcLnSwapToWallet(
      swapTx: updatedSwap,
      label: label,
      walletId: walletId,
    );
  }

  Future createBtcLnSubSwap({
    required String walletId,
    required String invoice,
    required int amount,
    String? label,
    required bool isTestnet,
    required String networkUrl,
  }) async {
    emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));
    final bloc = _homeCubit.state.getWalletBlocById(walletId);
    if (bloc == null) return;

    final wallet = bloc.state.wallet;
    if (wallet == null) return;

    final (fees, errFees) = await _swapBoltz.getFeesAndLimits(
      boltzUrl: boltzTestnet,
      outAmount: amount,
    );
    if (errFees != null) {
      emit(state.copyWith(errCreatingSwapInv: errFees.toString(), generatingSwapInv: false));
      return;
    }
    // check if decoded invoice amount is within limits

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
      // network: _networkCubit.state.testnet ? Chain.BitcoinTestnet : Chain.Bitcoin,
      // electrumUrl: _networkCubit.state.getNetworkUrl(),
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
      walletId: walletId,
      label: label,
    );
  }

  Future _saveBtcLnSwapToWallet({
    required String walletId,
    required SwapTx swapTx,
    String? label,
  }) async {
    final walletBloc = _homeCubit.state.getWalletBlocById(walletId);
    if (walletBloc == null) return;

    final wallet = walletBloc.state.wallet;
    if (wallet == null) return;

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

    walletBloc.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [UpdateWalletTypes.swaps],
      ),
    );

    // _homeCubit.updateSelectedWallet(walletBloc);
    await Future.delayed(const Duration(seconds: 5));

    _watchTxsBloc.add(WatchWalletTxs(walletId: walletId));
  }

  void clearSwapTx() => emit(state.copyWith(swapTx: null));
}
