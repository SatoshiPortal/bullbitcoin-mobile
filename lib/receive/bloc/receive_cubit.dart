import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
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
  }) : super(const ReceiveState()) {
    loadAddress();
  }
  final SettingsCubit settingsCubit;
  final WalletBloc walletBloc;
  final WalletAddress walletAddress;
  final HiveStorage hiveStorage;
  final WalletRepository walletRepository;

  void loadAddress() async {
    emit(state.copyWith(loadingAddress: true, errLoadingAddress: ''));

    final address = walletBloc.state.wallet!.lastGeneratedAddress;
    // lastGeneratedAddress in wallet should have updated label

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
    // emit(const ReceiveState());
    emit(
      state.copyWith(
        errLoadingAddress: '',
        savedInvoiceAmount: 0,
        invoiceAmount: 0,
      ),
    );
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
    // final errUpdate = await walletRepository.updateWallet(
    //   wallet: updatedWallet!,
    //   hiveStore: hiveStorage,
    // );
    // if (errUpdate != null) {
    //   emit(
    //     state.copyWith(
    //       savingLabel: false,
    //       errLoadingAddress: errUpdate.toString(),
    //     ),
    //   );
    //   return;
    // }
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
      settingsCubit.updateStopGap(addressGap + 1);
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

  void updateAmount(int amt) {
    emit(state.copyWith(invoiceAmount: amt));
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
      address: (state.defaultAddress!.index!, state.defaultAddress!.address),
      wallet: walletBloc.state.wallet!,
      label: state.privateLabel,
      kind: state.defaultAddress!.kind,
      state: state.defaultAddress!.state,
      spendable: state.defaultAddress!.spendable,
    );

    // final errUpdate = await walletRepository.updateWallet(
    //   wallet: w,
    //   hiveStore: hiveStorage,
    // );
    // if (errUpdate != null) {
    //   emit(
    //     state.copyWith(
    //       savingLabel: false,
    //       errSavingLabel: errUpdate.toString(),
    //     ),
    //   );
    //   return;
    // }
    // Future.delayed(const Duration(milliseconds: 100));

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

  // void invoiceClicked() {
  //   emit(
  //     state.copyWith(
  //       step: ReceiveStep.createInvoice,
  //       privateLabel: '',
  //     ),
  //   );
  // }

  // void saveInvoiceClicked() {
  //   if (state.invoiceAmount <= 0) {
  //     emit(state.copyWith(errCreatingInvoice: 'Enter correct amount'));
  //     return;
  //   }

  //   emit(
  //     state.copyWith(
  //       // step: ReceiveStep.enterPrivateLabel,
  //       errCreatingInvoice: '',
  //     ),
  //   );
  // }

  void loadInvoice() {
    if (state.savedDescription.isNotEmpty)
      emit(state.copyWith(description: state.savedDescription));
    if (state.savedInvoiceAmount > 0) emit(state.copyWith(invoiceAmount: state.savedInvoiceAmount));
  }

  void clearInvoiceFields() {
    emit(state.copyWith(invoiceAmount: 0, description: ''));
  }

  void saveFinalInvoiceClicked() async {
    if (state.invoiceAmount <= 0) {
      emit(state.copyWith(errCreatingInvoice: 'Enter correct amount'));
      return;
    }

    emit(state.copyWith(creatingInvoice: true, errCreatingInvoice: ''));

    // if (state.savedDescription.isEmpty || state.savedInvoiceAmount == 0) {
    //   final (a, err) = await walletAddress.newDeposit(bdkWallet: walletBloc.state.bdkWallet!);

    //   if (err != null)
    //     emit(
    //       state.copyWith(
    //         creatingInvoice: false,
    //         errCreatingInvoice: err.toString(),
    //       ),
    //     );

    //   final (savedAddress, w) = await walletAddress.addAddressToWallet(
    //     address: (a!.index, a.address),
    //     wallet: walletBloc.state.wallet!,
    //     label: state.privateLabel,
    //     kind: AddressKind.deposit,
    //   );

    //   final errUpdate = await walletRepository.updateWallet(
    //     wallet: w,
    //     hiveStore: hiveStorage,
    //   );
    //   if (errUpdate != null) {
    //     emit(
    //       state.copyWith(
    //         creatingInvoice: false,
    //         errCreatingInvoice: errUpdate.toString(),
    //       ),
    //     );
    //     return;
    //   }

    //   walletBloc.add(UpdateWallet(w));

    //   emit(state.copyWith(defaultAddress: savedAddress));
    // }

    // final btcAmt = (state.invoiceAmount / 100000000).toStringAsFixed(8);

    // final invoice = 'bitcoin:' + a.address + '?amount=' + btcAmt + '&label=' + state.description;
    // final invoice = BIP21(
    //   state.defaultAddress!.address,
    //   {'amount': state.invoiceAmount, 'label': state.description},
    // );
    emit(
      state.copyWith(
        creatingInvoice: false,
        errCreatingInvoice: '',
        savedDescription: state.description,
        description: '',
        savedInvoiceAmount: state.invoiceAmount,
        invoiceAmount: 0,
        // newInvoiceAddress: savedAddress,
        // step: ReceiveStep.showInvoice,
      ),
    );
  }

  void shareClicked() {}
}
