import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveCubit extends Cubit<ReceiveState> {
  ReceiveCubit({
    required this.walletBloc,
    required this.hiveStorage,
    required this.walletAddress,
    required this.walletRepository,
    required this.settingsCubit,
    required this.networkCubit,
    required this.currencyCubit,
  }) : super(const ReceiveState()) {
    loadAddress();
  }
  final SettingsCubit settingsCubit;
  final WalletBloc walletBloc;
  final WalletAddress walletAddress;
  final HiveStorage hiveStorage;
  final WalletRepository walletRepository;
  final NetworkCubit networkCubit;
  final CurrencyCubit currencyCubit;

  void loadAddress() async {
    emit(state.copyWith(loadingAddress: true, errLoadingAddress: ''));

    final address = walletBloc.state.wallet!.lastGeneratedAddress;

    emit(
      state.copyWith(
        defaultAddress: address,
      ),
    );
    final label = await walletAddress.getLabel(
      address: address!.address,
      wallet: walletBloc.state.wallet!,
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
    emit(
      state.copyWith(
        errLoadingAddress: '',
        savedInvoiceAmount: 0,
      ),
    );
    currencyCubit.updateAmountDirect(0);
    if (walletBloc.state.bdkWallet == null) {
      emit(state.copyWith(errLoadingAddress: 'Wallet Sync Required'));
      return;
    }
    final (updatedWallet, err) = await walletAddress.newAddress(
      wallet: walletBloc.state.wallet!,
      bdkWallet: walletBloc.state.bdkWallet!,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errLoadingAddress: err.toString(),
        ),
      );
      return;
    }

    walletBloc.add(UpdateWallet(updatedWallet!, updateTypes: [UpdateWalletTypes.addresses]));

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
      networkCubit.updateStopGap(addressGap + 1);
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
    if (state.privateLabel == (state.defaultAddress?.label ?? '')) return;

    emit(state.copyWith(savingLabel: true, errSavingLabel: ''));

    final (a, w) = await walletAddress.addAddressToWallet(
      address: (state.defaultAddress!.index, state.defaultAddress!.address),
      wallet: walletBloc.state.wallet!,
      label: state.privateLabel,
      kind: state.defaultAddress!.kind,
      state: state.defaultAddress!.state,
      spendable: state.defaultAddress!.spendable,
    );

    walletBloc.add(UpdateWallet(w, updateTypes: [UpdateWalletTypes.addresses]));

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
    currencyCubit.updateAmountDirect(0);
  }

  void saveFinalInvoiceClicked() async {
    if (currencyCubit.state.amount <= 0) {
      emit(state.copyWith(errCreatingInvoice: 'Enter correct amount'));
      return;
    }

    emit(state.copyWith(creatingInvoice: true, errCreatingInvoice: ''));

    final (_, w) = await walletAddress.addAddressToWallet(
      address: (state.defaultAddress!.index, state.defaultAddress!.address),
      wallet: walletBloc.state.wallet!,
      label: state.description,
      kind: AddressKind.deposit,
    );

    walletBloc.add(UpdateWallet(w, updateTypes: [UpdateWalletTypes.addresses]));

    emit(
      state.copyWith(
        creatingInvoice: false,
        errCreatingInvoice: '',
        savedDescription: state.description,
        description: '',
        savedInvoiceAmount: currencyCubit.state.amount,
      ),
    );
    currencyCubit.updateAmountDirect(0);
  }

  void shareClicked() {}

  void clearErrors() async {
    emit(
      state.copyWith(
        errCreatingInvoice: '',
        errLoadingAddress: '',
        errSavingLabel: '',
      ),
    );
  }
}
