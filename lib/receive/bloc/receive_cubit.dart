import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/payjoin/manager.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_repositories/app_wallets_repository.dart';
import 'package:bb_mobile/_repositories/wallet/wallet_storage.dart';
import 'package:bb_mobile/_repositories/wallet_service.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveCubit extends Cubit<ReceiveState> {
  ReceiveCubit({
    Wallet? wallet,
    required WalletAddress walletAddress,
    required WalletsStorageRepository walletsStorageRepository,
    required PayjoinManager payjoinManager,
    required AppWalletsRepository appWalletsRepository,
  })  : _walletsStorageRepository = walletsStorageRepository,
        _walletAddress = walletAddress,
        _payjoinManager = payjoinManager,
        _appWalletsRepository = appWalletsRepository,
        super(
          ReceiveState(
            wallet: wallet,
            oneWallet: wallet != null,
          ),
        ) {
    loadAddress();
    if (wallet != null) updateWallet(wallet, fromInit: true);
  }

  final WalletAddress _walletAddress;
  final WalletsStorageRepository _walletsStorageRepository;
  final PayjoinManager _payjoinManager;
  final AppWalletsRepository _appWalletsRepository;

  Future<void> updatePayjoinEndpoint(String payjoinEndpoint) async {
    emit(state.copyWith(payjoinEndpoint: payjoinEndpoint));
    return;
  }

  Future<void> updateWallet(
    Wallet wallet, {
    bool fromInit = false,
  }) async {
    if (state.oneWallet && !fromInit) return;
    emit(
      state.copyWith(
        wallet: wallet,
        defaultAddress: null,
        savedDescription: '',
        description: '',
      ),
    );

    if (state.paymentNetwork == PaymentNetwork.lightning) {
      emit(state.copyWith(defaultAddress: null));
      return;
    }

    if (!wallet.mainWallet) {
      emit(state.copyWith(paymentNetwork: PaymentNetwork.bitcoin));
    }

    await isPayjoinEnabled();
    await loadAddress();

    await payjoinInit();
  }

  Future<void> payjoinInit() async {
    final baseType = state.wallet!.baseWalletType;

    if (state.paymentNetwork == PaymentNetwork.bitcoin &&
        state.defaultAddress != null &&
        state.isPayjoin &&
        baseType == BaseWalletType.Bitcoin) {
      await receivePayjoin(
        state.wallet!.isTestnet(),
        state.defaultAddress!.address,
      );
    } else {
      emit(state.copyWith(payjoinReceiver: null));
    }
  }

  void updateWalletType(
    PaymentNetwork selectedPaymentNetwork,
    bool isTestnet, {
    bool onStart = false,
  }) {
    if (!state.allowedSwitch(selectedPaymentNetwork)) return;

    if (onStart) {
      emit(state.copyWith(paymentNetwork: selectedPaymentNetwork));
      return;
    }

    final currentPayNetwork = state.paymentNetwork;
    final walletType = state.wallet?.type;
    if (walletType == null) return;

    emit(state.copyWith(paymentNetwork: selectedPaymentNetwork));

    if (selectedPaymentNetwork == PaymentNetwork.lightning) {
      emit(state.copyWith(defaultAddress: null));
    }

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
  }

  void clearSwitch() {
    emit(state.copyWith(switchToSecure: false, switchToInstant: false));
  }

  Future<void> loadAddress() async {
    if (state.wallet == null) return;
    emit(state.copyWith(loadingAddress: true, errLoadingAddress: ''));

    final Wallet wallet = state.wallet!;

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
        loadingAddress: state
            .isPayjoin, // Keep loading while the payjoin receiver is being initialized, if it's enabled.
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

    final wallet = state.wallet;
    if (wallet == null) return;

    final address = wallet.getAddressFromWallet(defaultAddress.address);
    if (address == null) return;

    if (!isLiq && state.defaultAddress != null) {
      emit(state.copyWith(description: address.label ?? ''));
    }

    if (isLiq && state.defaultLiquidAddress != null) {
      emit(state.copyWith(description: address.label ?? ''));
    }
  }

  Future<void> generateNewAddress() async {
    if (state.paymentNetwork == PaymentNetwork.lightning) return;

    emit(
      state.copyWith(errLoadingAddress: '', savedInvoiceAmount: 0),
    );

    if (state.wallet == null) return;

    final wallet = state.wallet!;

    final (updatedWallet, err) = await _walletAddress.newAddress(wallet);
    if (err != null) {
      emit(
        state.copyWith(
          errLoadingAddress: err.toString(),
        ),
      );
      return;
    }

    await _appWalletsRepository.getWalletServiceById(wallet.id)?.updateWallet(
      updatedWallet!,
      updateTypes: [UpdateWalletTypes.addresses],
    );

    final addressGap = updatedWallet!.addressGap();
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
      emit(state.copyWith(updateAddressGap: addressGap + 1));
      Future.delayed(const Duration(milliseconds: 100));
    }
    if (wallet.isLiquid()) {
      emit(
        state.copyWith(
          defaultLiquidAddress: updatedWallet.lastGeneratedAddress,
        ),
      );
    } else {
      emit(
        state.copyWith(
          defaultAddress: updatedWallet.lastGeneratedAddress,
        ),
      );
    }

    emit(
      state.copyWith(
        defaultLiquidAddress: updatedWallet.lastGeneratedAddress,
        defaultAddress: updatedWallet.lastGeneratedAddress,
        savedDescription: '',
        description: '',
      ),
    );

    payjoinInit();
  }

  void descriptionChanged(String description) {
    emit(state.copyWith(description: description));
  }

  Future<void> saveAddrressLabel() async {
    if (state.wallet == null) return;

    if (state.description == state.defaultAddress?.label) return;

    emit(state.copyWith(savingLabel: true, errSavingLabel: ''));

    final address = state.paymentNetwork == PaymentNetwork.liquid
        ? state.defaultLiquidAddress
        : state.defaultAddress;

    final (a, w) = await _walletAddress.addAddressToWallet(
      address: (address!.index, address.address),
      wallet: state.wallet!,
      label: state.description,
      kind: address.kind,
      state: address.state,
    );

    await _appWalletsRepository
        .getWalletServiceById(state.wallet!.id)
        ?.updateWallet(
      w,
      updateTypes: [UpdateWalletTypes.addresses],
    );

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

  Future<void> receivePayjoin(bool isTestnet, String address) async {
    final receiver = await _payjoinManager.initReceiver(isTestnet, address);
    emit(
      state.copyWith(
        payjoinReceiver: receiver,
        loadingAddress:
            false, // Stop loading now that the receiver is initialized.
      ),
    );
    _payjoinManager.spawnNewReceiver(
      isTestnet: isTestnet,
      receiver: receiver,
      wallet: state.wallet!,
    );
  }

  Future<void> isPayjoinEnabled() async {
    final wallet = state.wallet;
    if (wallet == null) return;

    if (wallet.utxos.isEmpty) {
      emit(state.copyWith(isPayjoin: false));
    } else {
      emit(state.copyWith(isPayjoin: true));
    }
  }
}
