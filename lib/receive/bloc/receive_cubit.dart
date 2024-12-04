import 'package:bb_mobile/_model/swap.dart';
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
        super(
          ReceiveState(
            walletBloc: walletBloc,
            oneWallet: walletBloc != null,
          ),
        ) {
    loadAddress();
  }

  final WalletAddress _walletAddress;
  final WalletsStorageRepository _walletsStorageRepository;

  void updatePayjoinEndpoint(String payjoinEndpoint) {
    emit(
      state.copyWith(
        payjoinEndpoint: payjoinEndpoint,
      ),
    );
    return;
  }

  void updateWalletBloc(WalletBloc walletBloc) {
    if (state.oneWallet) return;
    emit(
      state.copyWith(
        walletBloc: walletBloc,
        defaultAddress: null,
        // privateLabel: '',
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

    if (!state.allowedSwitch(selectedPaymentNetwork)) return;

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
    if (wallet.isLiquid()) {
      emit(
        state.copyWith(
          defaultAddress: wallet.lastGeneratedAddress,
        ),
      );

      final (allWallets, _) = await _walletsStorageRepository.readAllWallets();

      final Wallet? liquidWallet;
      if (wallet.isMainnet()) {
        liquidWallet = allWallets?.firstWhere(
          (w) =>
              w.isLiquid() &&
              w.isMainnet() &&
              w.sourceFingerprint == wallet.sourceFingerprint,
        );
      } else {
        liquidWallet = allWallets?.firstWhere(
          (w) =>
              w.isLiquid() &&
              w.isTestnet() &&
              w.sourceFingerprint == wallet.sourceFingerprint,
        );
      }

      emit(
        state.copyWith(
          defaultLiquidAddress: liquidWallet?.lastGeneratedAddress,
        ),
      );
      // If currently selected wallet is liquid? wallet, then find and load the bitcoin wallet and get it's lastGeneratedAddress.
    } else if (wallet.isBitcoin()) {
      emit(
        state.copyWith(
          defaultLiquidAddress: wallet.lastGeneratedAddress,
        ),
      );

      final (allWallets, _) = await _walletsStorageRepository.readAllWallets();

      Wallet? btcWallet;
      if (wallet.isMainnet()) {
        btcWallet = allWallets?.firstWhere(
          (w) =>
              w.isBitcoin() &&
              w.isMainnet() &&
              w.sourceFingerprint == wallet.sourceFingerprint,
        );
      } else {
        btcWallet = allWallets?.firstWhere(
          (w) =>
              w.isBitcoin() &&
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

    _checkLabel();
  }

  void _checkLabel() {
    final isLn = state.paymentNetwork == PaymentNetwork.lightning;
    if (isLn) return;

    final isLiq = state.paymentNetwork == PaymentNetwork.liquid;
    final defaultAddress =
        isLiq ? state.defaultLiquidAddress : state.defaultAddress;
    if (defaultAddress == null) return;

    final wallet = state.walletBloc?.state.wallet;
    if (wallet == null) return;

    final address = wallet.getAddressFromWallet(defaultAddress.address);
    if (address == null) return;

    if (!isLiq && state.defaultAddress != null)
      emit(
        state.copyWith(description: address.label ?? ''),
      );

    if (isLiq && state.defaultLiquidAddress != null)
      emit(
        state.copyWith(description: address.label ?? ''),
      );
  }

  void generateNewAddress() async {
    if (state.paymentNetwork == PaymentNetwork.lightning) return;

    emit(
      state.copyWith(
        errLoadingAddress: '',
        savedInvoiceAmount: 0,
      ),
    );

    if (state.walletBloc == null) return;

    final wallet = state.walletBloc!.state.wallet!;

    final (updatedWallet, err) = await _walletAddress.newAddress(wallet);
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
    if (wallet.isLiquid())
      emit(
        state.copyWith(
          defaultLiquidAddress: updatedWallet.lastGeneratedAddress,
        ),
      );
    else
      emit(
        state.copyWith(
          defaultAddress: updatedWallet.lastGeneratedAddress,
        ),
      );

    emit(
      state.copyWith(
        defaultLiquidAddress: updatedWallet.lastGeneratedAddress,
        defaultAddress: updatedWallet.lastGeneratedAddress,
        // privateLabel: '',
        savedDescription: '',
        description: '',
      ),
    );
  }

  void descriptionChanged(String description) {
    emit(state.copyWith(description: description));
  }

  void saveAddrressLabel() async {
    if (state.walletBloc == null) return;

    if (state.description == state.defaultAddress?.label) return;

    emit(state.copyWith(savingLabel: true, errSavingLabel: ''));

    final address = state.paymentNetwork == PaymentNetwork.liquid
        ? state.defaultLiquidAddress
        : state.defaultAddress;

    final (a, w) = await _walletAddress.addAddressToWallet(
      address: (address!.index, address.address),
      wallet: state.walletBloc!.state.wallet!,
      label: state.description,
      kind: address.kind,
      state: address.state,
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

    await Future.delayed(const Duration(seconds: 2));

    emit(state.copyWith(labelSaved: false));
  }

  void clearInvoiceFields() {
    emit(state.copyWith(description: ''));
  }

  void shareClicked() {}
}
