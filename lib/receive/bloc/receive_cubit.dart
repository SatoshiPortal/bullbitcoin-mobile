import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveCubit extends Cubit<ReceiveState> {
  ReceiveCubit({
    WalletBloc? walletBloc,
    required this.hiveStorage,
    required this.secureStorage,
    required this.walletAddress,
    required this.walletsStorageRepository,
    required this.walletSensitiveRepository,
    required this.settingsCubit,
    required this.networkCubit,
    required this.currencyCubit,
    required this.walletTx,
    required SwapCubit swapBloc,
    required this.walletsRepository,
  }) : super(ReceiveState(walletBloc: walletBloc, swapBloc: swapBloc)) {
    loadAddress();
  }
  final SettingsCubit settingsCubit;
  final WalletAddress walletAddress;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletsStorageRepository walletsStorageRepository;
  final WalletSensitiveRepository walletSensitiveRepository;
  final NetworkCubit networkCubit;
  final CurrencyCubit currencyCubit;
  final WalletTx walletTx;
  final WalletsRepository walletsRepository;

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
    final watchOnly = walletBloc.state.wallet!.watchOnly();
    if (watchOnly) emit(state.copyWith(walletType: ReceiveWalletType.secure));
    loadAddress();
  }

  void updateWalletType(ReceiveWalletType walletType) {
    emit(state.copyWith(walletType: walletType));
    if (!networkCubit.state.testnet) return;

    if (walletType == ReceiveWalletType.lightning) {
      state.swapBloc.clearSwapTx();
      emit(state.copyWith(defaultAddress: null));
    } else {
      loadAddress();
    }
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
      state.swapBloc.clearSwapTx();
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

    final (bdkWallet, errLoading) = walletsRepository.getBdkWallet(state.walletBloc!.state.wallet!);
    if (errLoading != null) {
      emit(state.copyWith(errLoadingAddress: 'Wallet Sync Required'));
      return;
    }

    final (updatedWallet, err) = await walletAddress.newAddress(
      wallet: state.walletBloc!.state.wallet!,
      bdkWallet: bdkWallet!,
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
        savedInvoiceAmount: currencyCubit.state.amount,
      ),
    );
  }

  void createLnInvoiceClicked() async {
    final walletId = state.walletBloc?.state.wallet?.id;
    if (walletId == null) return;

    state.swapBloc.createBtcLnRevSwap(
      walletId: walletId,
      amount: currencyCubit.state.amount,
      label: state.description,
    );
  }

  void shareClicked() {}
}
