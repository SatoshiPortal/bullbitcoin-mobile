import 'package:bb_mobile/_pkg/storage.dart';
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
    try {
      emit(state.copyWith(loadingAddress: true, errLoadingAddress: ''));

      final (ai, err) = await walletUpdate.getNewAddress(
        wallet: walletCubit.state.wallet!,
        bdkWallet: walletCubit.state.bdkWallet!,
      );
      if (err != null) throw err.toString();

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
      if (errUpdate != null) throw errUpdate.toString();

      walletCubit.updateWallet(w);

      emit(
        state.copyWith(
          loadingAddress: false,
          errLoadingAddress: '',
          defaultAddress: a,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loadingAddress: false,
          errLoadingAddress: e.toString(),
        ),
      );
    }
  }

  // void toggleBtcUnit() {
  //   if (state.unit == BTCUnit.sats) {
  //     emit(state.copyWith(unit: BTCUnit.btc));
  //   } else {
  //     emit(state.copyWith(unit: BTCUnit.sats));
  //   }
  // }

  void updateAmount(int amt) {
    emit(state.copyWith(invoiceAmount: amt));
  }

  // void amountChanged(String amount) {
  //   if (state.unit == BTCUnit.btc) {
  //     final amountDouble = double.parse(amount);
  //     final amountSatoshi = (amountDouble * 100000000).toInt();
  //     emit(state.copyWith(invoiceAmount: amountSatoshi));
  //   } else {
  //     final amountInt = int.parse(amount);
  //     emit(state.copyWith(invoiceAmount: amountInt));
  //   }
  // }

  void descriptionChanged(String description) {
    emit(state.copyWith(description: description));
  }

  void privateLabelChanged(String privateLabel) {
    emit(state.copyWith(privateLabel: privateLabel));
  }

  void saveDefaultAddressLabel() async {
    try {
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
      if (errUpdate != null) throw errUpdate.toString();

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
    } catch (e) {
      emit(
        state.copyWith(
          savingLabel: false,
          errSavingLabel: e.toString(),
        ),
      );
    }
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
      state.copyWith(
          step: ReceiveStep.enterPrivateLabel, errCreatingInvoice: ''),
    );
  }

  void saveFinalInvoiceClicked() async {
    try {
      emit(state.copyWith(creatingInvoice: true, errCreatingInvoice: ''));

      // bdk.AddressInfo(index: 1, address: '');

      // final add = await bdk.Address.create(address: 'address');
      // final scr = await add.scriptPubKey();

      final (a, err) = await walletUpdate.newAddress(
          bdkWallet: walletCubit.state.bdkWallet!);

      if (err != null) throw err.toString();

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
      if (errUpdate != null) throw errUpdate.toString();

      walletCubit.updateWallet(w);

      final btcAmt = (state.invoiceAmount / 100000000).toStringAsFixed(8);

      final invoice = 'bitcoin:' +
          address +
          '?amount=' +
          btcAmt +
          '&label=' +
          state.description;

      emit(
        state.copyWith(
          creatingInvoice: false,
          errCreatingInvoice: '',
          invoiceAddress: invoice,
          newInvoiceAddress: savedAddress,
          step: ReceiveStep.showInvoice,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          creatingInvoice: false,
          errCreatingInvoice: e.toString(),
        ),
      );
    }
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
