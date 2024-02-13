import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveCubit extends Cubit<ReceiveState> {
  ReceiveCubit({
    WalletBloc? walletBloc,
    required this.hiveStorage,
    required this.secureStorage,
    required this.walletAddress,
    required this.walletRepository,
    required this.walletSensitiveRepository,
    required this.settingsCubit,
    required this.networkCubit,
    required this.currencyCubit,
    required this.swapBoltz,
    required this.walletTx,
  }) : super(ReceiveState(walletBloc: walletBloc)) {
    loadAddress();
  }
  final SettingsCubit settingsCubit;
  final WalletAddress walletAddress;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletRepository walletRepository;
  final WalletSensitiveRepository walletSensitiveRepository;
  final NetworkCubit networkCubit;
  final CurrencyCubit currencyCubit;
  final SwapBoltz swapBoltz;
  final WalletTx walletTx;

  void updateWalletBloc(WalletBloc walletBloc) {
    emit(
      state.copyWith(
        walletBloc: walletBloc,
        defaultAddress: null,
        privateLabel: '',
        savedDescription: '',
        description: '',
      ),
    );
    loadAddress();
  }

  void updateWalletType(ReceiveWalletType walletType) {
    emit(state.copyWith(walletType: walletType));
    if (!networkCubit.state.testnet) return;

    if (walletType == ReceiveWalletType.lightning) createBtcLightningInvoice();
  }

  void createBtcLightningInvoice() async {
    if (!networkCubit.state.testnet) return;

    final outAmount = currencyCubit.state.amount;
    if (outAmount < 50000) {
      emit(
        state.copyWith(
          errCreatingInvoice: 'Amount should be greater than 50000',
          creatingInvoice: false,
        ),
      );
      return;
    }

    emit(state.copyWith(creatingInvoice: true, errCreatingInvoice: ''));
    final (seed, errReadingSeed) = await walletSensitiveRepository.readSeed(
      fingerprintIndex: state.walletBloc!.state.wallet!.getRelatedSeedStorageString(),
      secureStore: secureStorage,
    );
    if (errReadingSeed != null) {
      emit(state.copyWith(errCreatingInvoice: errReadingSeed.toString(), creatingInvoice: false));
      return;
    }
    final (fees, errFees) = await SwapBoltz.getFeesAndLimits(
      boltzUrl: boltzTestnet,
      outAmount: outAmount,
    );
    if (errFees != null) {
      emit(state.copyWith(errCreatingInvoice: errFees.toString(), creatingInvoice: false));
      return;
    }

    final (swap, errCreatingInv) = await swapBoltz.receive(
      mnemonic: seed!.mnemonic,
      index: state.walletBloc!.state.wallet!.swapTxCount,
      outAmount: outAmount,
      network: Chain.Testnet,
      electrumUrl: networkCubit.state.getNetworkUrl(),
      boltzUrl: boltzTestnet,
      pairHash: fees!.btcPairHash,
    );
    if (errCreatingInv != null) {
      emit(state.copyWith(errCreatingInvoice: errCreatingInv.toString(), creatingInvoice: false));
      return;
    }

    emit(
      state.copyWith(
        creatingInvoice: false,
        errCreatingInvoice: '',
        defaultAddress: null,
        swapTx: swap,
      ),
    );
    _watchInvoiceStatus();
    _saveSwapInvoiceToWallet();
  }

  void _saveSwapInvoiceToWallet() async {
    if (state.swapTx == null) return;
    if (state.walletBloc == null) return;

    final wallet = state.walletBloc!.state.wallet!;
    final swapTxCount = wallet.swapTxCount + 1;

    final (updatedWallet, err) = await walletTx.addUnsignedTxToWallet(
      wallet: wallet.copyWith(swapTxCount: swapTxCount),
      transaction: Transaction.fromSwapTx(state.swapTx!),
    );
    if (err != null) {
      emit(state.copyWith(errCreatingInvoice: err.toString(), creatingInvoice: false));
      return;
    }

    final errr = await walletRepository.updateWallet(
      wallet: updatedWallet,
      hiveStore: hiveStorage,
    );
    if (errr != null) {
      emit(state.copyWith(errCreatingInvoice: errr.toString(), creatingInvoice: false));
      return;
    }

    state.walletBloc!.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [UpdateWalletTypes.transactions],
      ),
    );
  }

  void _watchInvoiceStatus() async {
    if (state.swapTx == null) return;
    final swap = state.swapTx!;
    emit(state.copyWith(swapTx: swap.copyWith(isListening: true)));
    final err = await swapBoltz.watchSwap(
      swapId: state.swapTx!.id,
      onUpdate: handleSwapStatusChange,
    );
    if (err != null) {
      emit(state.copyWith(errCreatingInvoice: err.toString(), creatingInvoice: false));
      return;
    }
  }

  void handleSwapStatusChange(String id, SwapStatus status) async {
    if (state.swapTx == null) return;
    if (state.swapTx!.id != id) return;
    final swap = state.swapTx!.copyWith(status: status);
    emit(state.copyWith(swapTx: swap));
    if (status == SwapStatus.invoiceSettled) {
      emit(state.copyWith(swapTx: swap.copyWith(isListening: false)));
      final err = swapBoltz.closeStream(swap.id);
      if (err != null) {
        emit(state.copyWith(errCreatingInvoice: err.toString()));
        return;
      }
    }
  }

  void resetToNewLnInvoice() async {
    if (state.walletBloc == null) return;

    emit(
      state.copyWith(
        errLoadingAddress: '',
        savedInvoiceAmount: 0,
        errCreatingInvoice: '',
        defaultAddress: null,
        swapTx: null,
      ),
    );
    currencyCubit.reset();
  }

  void loadAllSwapTxs() {
    if (state.walletBloc == null) return;
    final swapTxs = state.walletBloc!.state.wallet!.transactions.where((tx) => tx.isSwap).toList();
    emit(state.copyWith(swapTxs: swapTxs));
  }

  void loadAddress() async {
    if (state.walletBloc == null) return;
    emit(state.copyWith(loadingAddress: true, errLoadingAddress: ''));

    final address = state.walletBloc!.state.wallet!.lastGeneratedAddress;

    emit(
      state.copyWith(
        defaultAddress: address,
      ),
    );
    final label = await walletAddress.getLabel(
      address: address!.address,
      wallet: state.walletBloc!.state.wallet!,
    );
    final labelUpdated = address.copyWith(label: label);

    if (label != null) emit(state.copyWith(privateLabel: label, defaultAddress: labelUpdated));

    emit(
      state.copyWith(
        loadingAddress: false,
        errLoadingAddress: '',
      ),
    );
  }

  void generateNewAddress() async {
    if (state.walletType == ReceiveWalletType.lightning) {
      resetToNewLnInvoice();
      return;
    }

    emit(
      state.copyWith(
        errLoadingAddress: '',
        savedInvoiceAmount: 0,
      ),
    );
    currencyCubit.updateAmountDirect(0);

    if (state.walletBloc == null) return;

    if (state.walletBloc!.state.bdkWallet == null) {
      emit(state.copyWith(errLoadingAddress: 'Wallet Sync Required'));
      return;
    }
    final (updatedWallet, err) = await walletAddress.newAddress(
      wallet: state.walletBloc!.state.wallet!,
      bdkWallet: state.walletBloc!.state.bdkWallet!,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errLoadingAddress: err.toString(),
        ),
      );
      return;
    }

    state.walletBloc!.add(UpdateWallet(updatedWallet!, updateTypes: [UpdateWalletTypes.addresses]));

    final addressGap = updatedWallet.addressGap();
    if (addressGap >= 5 && addressGap <= 20) {
      emit(
        state.copyWith(
          errLoadingAddress:
              'Careful! Generating too many addresses will affect the global sync time.\n\nCurrent Gap: $addressGap.',
        ),
      );
    }

    if (addressGap > 20) {
      emit(
        state.copyWith(
          errLoadingAddress:
              'WARNING! Electrum stop gap has been increased to $addressGap. This will affect your wallet sync time.\nGoto WalletSettings->Addresses to see all generated addresses.',
        ),
      );
      networkCubit.updateStopGapAndSave(addressGap + 1);
      Future.delayed(const Duration(milliseconds: 100));
    }

    emit(
      state.copyWith(
        defaultAddress: updatedWallet.lastGeneratedAddress,
        privateLabel: '',
        savedDescription: '',
        description: '',
      ),
    );
  }

  void descriptionChanged(String description) {
    emit(state.copyWith(description: description));
  }

  void privateLabelChanged(String privateLabel) {
    emit(state.copyWith(privateLabel: privateLabel));
  }

  void clearLabelField() {
    emit(state.copyWith(privateLabel: ''));
  }

  void saveDefaultAddressLabel() async {
    if (state.walletBloc == null) return;

    if (state.privateLabel == (state.defaultAddress?.label ?? '')) return;

    emit(state.copyWith(savingLabel: true, errSavingLabel: ''));

    final (a, w) = await walletAddress.addAddressToWallet(
      address: (state.defaultAddress!.index, state.defaultAddress!.address),
      wallet: state.walletBloc!.state.wallet!,
      label: state.privateLabel,
      kind: state.defaultAddress!.kind,
      state: state.defaultAddress!.state,
      spendable: state.defaultAddress!.spendable,
    );

    state.walletBloc!.add(UpdateWallet(w, updateTypes: [UpdateWalletTypes.addresses]));

    emit(
      state.copyWith(
        savingLabel: false,
        labelSaved: true,
        errSavingLabel: '',
        defaultAddress: a,
      ),
    );
  }

  void loadInvoice() {
    if (state.savedDescription.isNotEmpty)
      emit(state.copyWith(description: state.savedDescription));
    if (state.savedInvoiceAmount > 0) currencyCubit.updateAmountDirect(state.savedInvoiceAmount);
  }

  void clearInvoiceFields() {
    emit(state.copyWith(description: ''));
    currencyCubit.reset();
    // currencyCubit.updateAmountDirect(0);
  }

  void saveFinalInvoiceClicked() async {
    if (state.walletBloc == null) return;

    if (currencyCubit.state.amount <= 0) {
      emit(state.copyWith(errCreatingInvoice: 'Enter correct amount'));
      return;
    }

    emit(state.copyWith(creatingInvoice: true, errCreatingInvoice: ''));

    final (_, w) = await walletAddress.addAddressToWallet(
      address: (state.defaultAddress!.index, state.defaultAddress!.address),
      wallet: state.walletBloc!.state.wallet!,
      label: state.description,
      kind: AddressKind.deposit,
    );

    state.walletBloc!.add(UpdateWallet(w, updateTypes: [UpdateWalletTypes.addresses]));

    emit(
      state.copyWith(
        creatingInvoice: false,
        errCreatingInvoice: '',
        savedDescription: state.description,
        // description: '',
        savedInvoiceAmount: currencyCubit.state.amount,
      ),
    );
    // currencyCubit.updateAmountDirect(0);
  }

  void shareClicked() {}
}
