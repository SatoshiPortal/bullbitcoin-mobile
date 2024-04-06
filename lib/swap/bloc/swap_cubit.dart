import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_state.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_event.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapCubit extends Cubit<SwapState> {
  SwapCubit({
    required this.hiveStorage,
    required this.secureStorage,
    required this.walletAddress,
    required this.walletsStorageRepository,
    required this.walletSensitiveRepository,
    required this.settingsCubit,
    required this.networkCubit,
    required this.swapBoltz,
    required this.walletTx,
    required this.walletTransaction,
    required this.watchTxsBloc,
    required this.homeCubit,
  }) : super(const SwapState()) {
    // clearSwapTx();
  }

  final SettingsCubit settingsCubit;
  final WalletAddress walletAddress;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletsStorageRepository walletsStorageRepository;
  final WalletSensitiveStorageRepository walletSensitiveRepository;
  final WalletTx walletTransaction;
  final NetworkCubit networkCubit;
  final SwapBoltz swapBoltz;
  final WalletTx walletTx;
  final WatchTxsBloc watchTxsBloc;
  final HomeCubit homeCubit;

  void decodeInvoice(String invoice) async {
    final (inv, err) = await swapBoltz.decodeInvoice(invoice: invoice);
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
  }) async {
    if (!networkCubit.state.testnet) return;

    final bloc = homeCubit.state.getWalletBlocById(walletId);
    if (bloc == null) return;

    final outAmount = amount;
    final (fees, errFees) = await swapBoltz.getFeesAndLimits(
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
    final (seed, errReadingSeed) = await walletSensitiveRepository.readSeed(
      fingerprintIndex: bloc.state.wallet!.getRelatedSeedStorageString(),
    );
    if (errReadingSeed != null) {
      emit(state.copyWith(errCreatingSwapInv: errReadingSeed.toString(), generatingSwapInv: false));
      return;
    }

    final (swap, errCreatingInv) = await swapBoltz.receive(
      mnemonic: seed!.mnemonic,
      index: bloc.state.wallet!.revKeyIndex,
      outAmount: outAmount,
      network: Chain.Testnet,
      electrumUrl: networkCubit.state.getNetworkUrl(),
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
  }) async {
    emit(state.copyWith(generatingSwapInv: true, errCreatingSwapInv: ''));
    final bloc = homeCubit.state.getWalletBlocById(walletId);
    if (bloc == null) return;

    final wallet = bloc.state.wallet;
    if (wallet == null) return;

    final (fees, errFees) = await swapBoltz.getFeesAndLimits(
      boltzUrl: boltzTestnet,
      outAmount: amount,
    );
    if (errFees != null) {
      emit(state.copyWith(errCreatingSwapInv: errFees.toString(), generatingSwapInv: false));
      return;
    }
    // check if decoded invoice amount is within limits

    final (seed, errReadingSeed) = await walletSensitiveRepository.readSeed(
      fingerprintIndex: wallet.getRelatedSeedStorageString(),
    );
    if (errReadingSeed != null) {
      emit(state.copyWith(errCreatingSwapInv: errReadingSeed.toString(), generatingSwapInv: false));
      return;
    }

    final (swap, err) = await swapBoltz.send(
      boltzUrl: boltzTestnet,
      pairHash: fees!.btcPairHash,
      mnemonic: seed!.mnemonic,
      index: wallet.revKeyIndex,
      invoice: invoice,
      network: Chain.Testnet,
      electrumUrl: networkCubit.state.getNetworkUrl(),
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
    final walletBloc = homeCubit.state.getWalletBlocById(walletId);
    if (walletBloc == null) return;

    final wallet = walletBloc.state.wallet;
    if (wallet == null) return;

    final (updatedWallet, err) = await walletTx.addSwapTxToWallet(
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

    homeCubit.updateSelectedWallet(walletBloc);
    await Future.delayed(const Duration(seconds: 5));

    watchTxsBloc.add(WatchWalletTxs(walletId: walletId));
  }

  void clearSwapTx() => emit(state.copyWith(swapTx: null));
}
