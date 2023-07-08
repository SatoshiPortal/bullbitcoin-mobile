import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveCubit extends Cubit<ReceiveState> {
  ReceiveCubit({
    required this.walletCubit,
    required this.walletUpdate,
    required this.storage,
    required this.walletRead,
  }) : super(const ReceiveState()) {
    loadAddress();
  }

  final WalletCubit walletCubit;
  final WalletUpdate walletUpdate;
  final IStorage storage;
  final WalletRead walletRead;

  void loadAddress() async {
    emit(state.copyWith(loadingAddress: true, errLoadingAddress: ''));

    final (ai, err) = await walletUpdate.getNewAddress(
      wallet: walletCubit.state.wallet!,
      bdkWallet: walletCubit.state.bdkWallet!,
    );
    if (err != null) {
      emit(
        state.copyWith(
          loadingAddress: false,
          errLoadingAddress: err.toString(),
        ),
      );
      return;
    }

    final (idx, address, label) = ai!;

    final (a, w) = await walletUpdate.updateWalletAddress(
      address: (idx, address),
      wallet: walletCubit.state.wallet!,
      label: label,
    );

    final errUpdate = await walletUpdate.updateWallet(
      wallet: w,
      walletRead: walletRead,
      storage: storage,
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

    walletCubit.updateWallet(w);

    emit(
      state.copyWith(
        loadingAddress: false,
        errLoadingAddress: '',
        defaultAddress: a,
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

  void saveDefaultAddressLabel() async {
    if (state.privateLabel == (state.defaultAddress?.label ?? '')) return;

    emit(state.copyWith(savingLabel: true, errSavingLabel: ''));

    final (a, w) = await walletUpdate.updateWalletAddress(
      address: (state.defaultAddress!.index, state.defaultAddress!.address),
      wallet: walletCubit.state.wallet!,
      label: state.privateLabel,
    );

    final errUpdate = await walletUpdate.updateWallet(
      wallet: w,
      walletRead: walletRead,
      storage: storage,
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

    walletCubit.updateWallet(w);

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

  void invoiceClicked() {
    emit(
      state.copyWith(
        step: ReceiveStep.createInvoice,
        privateLabel: '',
      ),
    );
  }

  void saveInvoiceClicked() {
    if (state.invoiceAmount <= 0) {
      emit(state.copyWith(errCreatingInvoice: 'Enter correct amount'));
      return;
    }

    emit(
      state.copyWith(step: ReceiveStep.enterPrivateLabel, errCreatingInvoice: ''),
    );
  }

  void saveFinalInvoiceClicked() async {
    emit(state.copyWith(creatingInvoice: true, errCreatingInvoice: ''));

    // bdk.AddressInfo(index: 1, address: '');

    // final add = await bdk.Address.create(address: 'address');
    // final scr = await add.scriptPubKey();

    final (a, err) = await walletUpdate.newAddress(bdkWallet: walletCubit.state.bdkWallet!);

    if (err != null)
      emit(
        state.copyWith(
          creatingInvoice: false,
          errCreatingInvoice: err.toString(),
        ),
      );

    final (idx, address) = a!;

    final (savedAddress, w) = await walletUpdate.updateWalletAddress(
      address: (idx, address),
      wallet: walletCubit.state.wallet!,
      label: state.privateLabel,
    );

    final errUpdate = await walletUpdate.updateWallet(
      wallet: w,
      walletRead: walletRead,
      storage: storage,
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

    walletCubit.updateWallet(w);

    final btcAmt = (state.invoiceAmount / 100000000).toStringAsFixed(8);

    final invoice = 'bitcoin:' + address + '?amount=' + btcAmt + '&label=' + state.description;

    emit(
      state.copyWith(
        creatingInvoice: false,
        errCreatingInvoice: '',
        invoiceAddress: invoice,
        newInvoiceAddress: savedAddress,
        step: ReceiveStep.showInvoice,
      ),
    );
  }

  void shareClicked() {}
}

// mxTi8bUNMjYWM769B6d9ZMnphTMxL2sRbK
// tb1qrqzgsjg7k3gdcmy8933ml46me7wmuetruttvag

      // } else {
      //   final defaultAddress = addresses.first;
      //   // .firstWhere(
      //   //   (element) => element.index == 0,
      //   // );

      //   // final defaultAddress = await state.bdkWallet.getAddress(
      //   //   addressIndex: const bdk.AddressIndex.lastUnused(),
      //   // );

      //   emit(
      //     state.copyWith(
      //       loadingAddress: false,
      //       errLoadingAddress: '',
      //       defaultAddress: defaultAddress,
      //     ),
      //   );
      // }
