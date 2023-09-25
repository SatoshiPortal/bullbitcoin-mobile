import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveCubit extends Cubit<ReceiveState> {
  ReceiveCubit({
    required this.walletBloc,
    required this.hiveStorage,
    required this.walletAddress,
    required this.walletRepository,
  }) : super(const ReceiveState()) {
    loadAddress();
  }

  final WalletBloc walletBloc;
  final WalletAddress walletAddress;
  final HiveStorage hiveStorage;
  final WalletRepository walletRepository;

  void loadAddress() async {
    emit(state.copyWith(loadingAddress: true, errLoadingAddress: ''));

    final syncing = walletBloc.state.syncing;
    if (syncing) {
      final newAddress = walletBloc.state.newAddress;
      final addresses = walletBloc.state.wallet!.addresses;
      final firstAddress = walletBloc.state.firstAddress;

      final address = newAddress == null
          ? addresses.isNotEmpty
              ? addresses.last.address
              : firstAddress
          : newAddress.address;
      final idx = newAddress == null
          ? addresses.isNotEmpty
              ? addresses.last.index
              : 0
          : newAddress.index;

      // final label = await walletAddress.getLabel(
      //   wallet: walletBloc.state.wallet!,
      //   address: address,
      // );

      // final (a, w) = await walletAddress.addAddressToWallet(
      //   address: (idx, address),
      //   wallet: walletBloc.state.wallet!,
      //   label: label,
      // );

      emit(
        state.copyWith(
          defaultAddress: Address(
            address: address,
            index: idx,
            kind: AddressKind.deposit,
            state: AddressStatus.unused,
          ),
        ),
      );

      // final errUpdate = await walletRepository.updateWallet(
      //   wallet: w,
      //   hiveStore: hiveStorage,
      // );
      // if (errUpdate != null) {
      //   emit(
      //     state.copyWith(
      //       loadingAddress: false,
      //       errLoadingAddress: errUpdate.toString(),
      //     ),
      //   );
      //   return;
      // }

      // walletBloc.add(UpdateWallet(w));
    } else {
      final wallet = walletBloc.state.wallet!;

      final (walletUpdated, wErr) = await walletAddress.loadAddresses(
        wallet: wallet,
        bdkWallet: walletBloc.state.bdkWallet!,
      );

      if (wErr != null) {
        emit(
          state.copyWith(
            loadingAddress: false,
            errLoadingAddress: wErr.toString(),
          ),
        );
        return;
      }

      // final label = await walletAddress.getLabel(
      //   wallet: walletBloc.state.wallet!,
      //   address: newAddress!.address,
      // );

      // final (a, w) = await walletAddress.addAddressToWallet(
      //   address: (newAddress.index, newAddress.address),
      //   wallet: walletBloc.state.wallet!,
      //   label: label,
      // );

      emit(state.copyWith(defaultAddress: walletUpdated!.lastUnusedAddress));

      final errUpdate = await walletRepository.updateWallet(
        wallet: walletUpdated,
        hiveStore: hiveStorage,
      );
      if (errUpdate != null) {
        emit(
          state.copyWith(
            loadingAddress: false,
            errLoadingAddress: errUpdate.toString(),
          ),
        );
        return;
      }

      walletBloc.add(UpdateWallet(walletUpdated));
    }

    await Future.delayed(200.ms);

    if (state.defaultAddress != null) {
      final defaultAddress = state.defaultAddress;
      final label = await walletAddress.getLabel(
        address: defaultAddress!.address,
        wallet: walletBloc.state.wallet!,
      );
      if (label != null) emit(state.copyWith(privateLabel: label));
    }

    emit(
      state.copyWith(
        loadingAddress: false,
        errLoadingAddress: '',
      ),
    );
  }

  void generateNewAddress() async {
    emit(const ReceiveState());
    loadAddress();
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
    );

    final errUpdate = await walletRepository.updateWallet(
      wallet: w,
      hiveStore: hiveStorage,
    );
    if (errUpdate != null) {
      emit(
        state.copyWith(
          savingLabel: false,
          errSavingLabel: errUpdate.toString(),
        ),
      );
      return;
    }

    walletBloc.add(UpdateWallet(w));

    emit(
      state.copyWith(
        privateLabel: '',
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

    if (state.savedDescription.isEmpty || state.savedInvoiceAmount == 0) {
      final (a, err) = await walletAddress.newDeposit(bdkWallet: walletBloc.state.bdkWallet!);

      if (err != null)
        emit(
          state.copyWith(
            creatingInvoice: false,
            errCreatingInvoice: err.toString(),
          ),
        );

      final (savedAddress, w) = await walletAddress.addAddressToWallet(
        address: (a!.index, a.address),
        wallet: walletBloc.state.wallet!,
        label: state.privateLabel,
      );

      final errUpdate = await walletRepository.updateWallet(
        wallet: w,
        hiveStore: hiveStorage,
      );
      if (errUpdate != null) {
        emit(
          state.copyWith(
            creatingInvoice: false,
            errCreatingInvoice: errUpdate.toString(),
          ),
        );
        return;
      }

      walletBloc.add(UpdateWallet(w));

      emit(state.copyWith(defaultAddress: savedAddress));
    }

    // final btcAmt = (state.invoiceAmount / 100000000).toStringAsFixed(8);

    // final invoice = 'bitcoin:' + a.address + '?amount=' + btcAmt + '&label=' + state.description;

    emit(
      state.copyWith(
        creatingInvoice: false,
        errCreatingInvoice: '',
        savedDescription: state.description,
        description: '',
        savedInvoiceAmount: state.invoiceAmount,
        invoiceAmount: 0,
        // invoiceAddress: invoice,
        // newInvoiceAddress: savedAddress,
        // step: ReceiveStep.showInvoice,
      ),
    );
  }

  void shareClicked() {}
}
