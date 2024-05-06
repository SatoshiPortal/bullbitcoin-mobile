import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveCubit extends Cubit<ReceiveState> {
  ReceiveCubit({
    WalletBloc? walletBloc,
    required WalletAddress walletAddress,
    required WalletsStorageRepository walletsStorageRepository,
  })  : _walletsStorageRepository = walletsStorageRepository,
        _walletAddress = walletAddress,
        super(ReceiveState(walletBloc: walletBloc)) {
    loadAddress();
  }

  final WalletAddress _walletAddress;
  final WalletsStorageRepository _walletsStorageRepository;

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

    if (state.paymentNetwork == PaymentNetwork.lightning)
      emit(state.copyWith(defaultAddress: null));

    if (!walletBloc.state.wallet!.mainWallet)
      emit(state.copyWith(paymentNetwork: PaymentNetwork.bitcoin));

    // final watchOnly = walletBloc.state.wallet!.watchOnly();
    // if (watchOnly)
    //   emit(state.copyWith(paymentNetwork: ReceivePaymentNetwork.bitcoin));
    loadAddress();
  }

  void updateWalletType(
    PaymentNetwork selectedPaymentNetwork,
    bool isTestnet, {
    bool onStart = false,
  }) {
    // if (!isTestnet) return;

    if (onStart) {
      emit(state.copyWith(paymentNetwork: selectedPaymentNetwork));
      return;
    }

    final currentPayNetwork = state.paymentNetwork;
    final walletType = state.walletBloc?.state.wallet?.type;
    if (walletType == null) return;

    emit(state.copyWith(paymentNetwork: selectedPaymentNetwork));

    if (selectedPaymentNetwork == PaymentNetwork.lightning)
      emit(state.copyWith(defaultAddress: null));

    if (selectedPaymentNetwork != PaymentNetwork.bitcoin) loadAddress();

    if (currentPayNetwork != PaymentNetwork.bitcoin &&
        selectedPaymentNetwork == PaymentNetwork.bitcoin) {
      emit(state.copyWith(switchToSecure: true));
      return;
    }

    if (currentPayNetwork != PaymentNetwork.lightning &&
        selectedPaymentNetwork == PaymentNetwork.lightning) {
      emit(state.copyWith(switchToInstant: true));
      return;
    }

    if (currentPayNetwork != PaymentNetwork.liquid &&
        selectedPaymentNetwork == PaymentNetwork.liquid) {
      emit(state.copyWith(switchToInstant: true));
      return;
    }

    // if (walletType == BBWalletType.instant &&
    //     currentPayNetwork != ReceivePaymentNetwork.bitcoin &&
    //     selectedPaymentNetwork == ReceivePaymentNetwork.bitcoin) {
    //   emit(state.copyWith(switchToSecure: true));
    //   return;
    // }

    // if (walletType == BBWalletType.instant &&
    //     currentPayNetwork != ReceivePaymentNetwork.liquid &&
    //     selectedPaymentNetwork == ReceivePaymentNetwork.liquid) {
    //   return;
    // }

    // if (walletType == BBWalletType.secure &&
    //     currentPayNetwork != ReceivePaymentNetwork.lightning &&
    //     selectedPaymentNetwork == ReceivePaymentNetwork.lightning) {
    //   // Allow LN -> BTC swap
    //   return;
    // }

    // if (walletType == BBWalletType.secure &&
    //     currentPayNetwork != ReceivePaymentNetwork.liquid &&
    //     selectedPaymentNetwork == ReceivePaymentNetwork.liquid) {
    //   // Allow LBTC -> BTC swap
    //   return;
    // }
  }

  void clearSwitch() {
    emit(state.copyWith(switchToSecure: false, switchToInstant: false));
  }

  void loadAddress() async {
    if (state.walletBloc == null) return;
    emit(state.copyWith(loadingAddress: true, errLoadingAddress: ''));

    final Wallet wallet = state.walletBloc!.state.wallet!;

    // If currently selected wallet is bitcoin? wallet, then find and load the liquid wallet and get it's lastGeneratedAddress.
    if (wallet.baseWalletType == BaseWalletType.Liquid) {
      emit(
        state.copyWith(
          defaultAddress: wallet.lastGeneratedAddress,
        ),
      );

      final (allWallets, _) = await _walletsStorageRepository.readAllWallets();

      final Wallet? liquidWallet;
      if (wallet.network == BBNetwork.Mainnet) {
        liquidWallet = allWallets?.firstWhere(
          (w) =>
              w.baseWalletType == BaseWalletType.Liquid &&
              w.network == BBNetwork.Mainnet &&
              w.sourceFingerprint == wallet.sourceFingerprint,
        );
      } else {
        liquidWallet = allWallets?.firstWhere(
          (w) =>
              w.baseWalletType == BaseWalletType.Liquid &&
              w.network == BBNetwork.Testnet &&
              w.sourceFingerprint == wallet.sourceFingerprint,
        );
      }

      emit(
        state.copyWith(
          defaultLiquidAddress: liquidWallet?.lastGeneratedAddress,
        ),
      );
      // If currently selected wallet is liquid? wallet, then find and load the bitcoin wallet and get it's lastGeneratedAddress.
    } else if (wallet.baseWalletType == BaseWalletType.Bitcoin) {
      emit(
        state.copyWith(
          defaultLiquidAddress: wallet.lastGeneratedAddress,
        ),
      );

      final (allWallets, _) = await _walletsStorageRepository.readAllWallets();

      Wallet? btcWallet;
      if (wallet.network == BBNetwork.Mainnet) {
        btcWallet = allWallets?.firstWhere(
          (w) =>
              w.baseWalletType == BaseWalletType.Bitcoin &&
              w.network == BBNetwork.Mainnet &&
              w.sourceFingerprint == wallet.sourceFingerprint,
        );
      } else {
        btcWallet = allWallets?.firstWhere(
          (w) =>
              w.baseWalletType == BaseWalletType.Bitcoin &&
              w.network == BBNetwork.Testnet &&
              w.sourceFingerprint == wallet.sourceFingerprint,
        );
      }

      emit(
        state.copyWith(
          defaultAddress: btcWallet?.lastGeneratedAddress,
        ),
      );
    }

    emit(
      state.copyWith(
        loadingAddress: false,
        errLoadingAddress: '',
      ),
    );
  }

  /*
  void loadAddress() async {
    if (state.walletBloc == null) return;
    emit(state.copyWith(loadingAddress: true, errLoadingAddress: ''));

    final address = state.walletBloc!.state.wallet!.getLastAddress();
    if (address == null) {
      generateNewAddress();
      emit(
        state.copyWith(
          loadingAddress: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        defaultAddress: address,
      ),
    );
    final label = await walletAddress.getLabel(
      address: address.address,
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
  */

  void generateNewAddress() async {
    if (state.paymentNetwork == PaymentNetwork.lightning) return;

    emit(
      state.copyWith(
        errLoadingAddress: '',
        savedInvoiceAmount: 0,
      ),
    );

    if (state.walletBloc == null) return;

    final (updatedWallet, err) = await _walletAddress.newAddress(
      state.walletBloc!.state.wallet!,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errLoadingAddress: err.toString(),
        ),
      );
      return;
    }

    state.walletBloc!.add(
      UpdateWallet(
        updatedWallet!,
        updateTypes: [UpdateWalletTypes.addresses],
      ),
    );

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
      // _networkCubit.updateStopGapAndSave(addressGap + 1);
      emit(state.copyWith(updateAddressGap: addressGap + 1));
      Future.delayed(const Duration(milliseconds: 100));
    }

    final wallet = state.walletBloc!.state.wallet!;
    if (wallet.type == BBWalletType.instant) {
      emit(
        state.copyWith(
          defaultLiquidAddress: updatedWallet.lastGeneratedAddress,
          privateLabel: '',
          savedDescription: '',
          description: '',
        ),
      );
    } else {
      emit(
        state.copyWith(
          defaultAddress: updatedWallet.lastGeneratedAddress,
          privateLabel: '',
          savedDescription: '',
          description: '',
        ),
      );
    }
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

    final (a, w) = await _walletAddress.addAddressToWallet(
      address: (state.defaultAddress!.index, state.defaultAddress!.address),
      wallet: state.walletBloc!.state.wallet!,
      label: state.privateLabel,
      kind: state.defaultAddress!.kind,
      state: state.defaultAddress!.state,
      spendable: state.defaultAddress!.spendable,
    );

    state.walletBloc!
        .add(UpdateWallet(w, updateTypes: [UpdateWalletTypes.addresses]));

    emit(
      state.copyWith(
        savingLabel: false,
        labelSaved: true,
        errSavingLabel: '',
        defaultAddress: a,
      ),
    );
  }

  // void loadInvoice() {
  //   if (state.savedDescription.isNotEmpty)
  //     emit(state.copyWith(description: state.savedDescription));
  //   if (state.savedInvoiceAmount > 0) currencyCubfit.updateAmountDirect(state.savedInvoiceAmount);
  // }

  void clearInvoiceFields() {
    emit(state.copyWith(description: ''));
  }

  void saveFinalInvoiceClicked(int amt) async {
    if (state.walletBloc == null) return;

    if (amt <= 0) {
      emit(state.copyWith(errCreatingInvoice: 'Enter correct amount'));
      return;
    }

    emit(state.copyWith(creatingInvoice: true, errCreatingInvoice: ''));

    final (_, w) = await _walletAddress.addAddressToWallet(
      address: (state.defaultAddress!.index, state.defaultAddress!.address),
      wallet: state.walletBloc!.state.wallet!,
      label: state.description,
      kind: AddressKind.deposit,
    );

    state.walletBloc!
        .add(UpdateWallet(w, updateTypes: [UpdateWalletTypes.addresses]));

    emit(
      state.copyWith(
        creatingInvoice: false,
        errCreatingInvoice: '',
        savedDescription: state.description,
        savedInvoiceAmount: amt,
      ),
    );
  }

  // void createLnInvoiceClicked(int amt) async {
  //   final walletId = state.walletBloc?.state.wallet?.id;
  //   if (walletId == null) return;

  //   state.swapBloc.createBtcLnRevSwap(
  //     walletId: walletId,
  //     amount: amt,
  //     label: state.description,
  //   );
  // }

  void shareClicked() {}
}
