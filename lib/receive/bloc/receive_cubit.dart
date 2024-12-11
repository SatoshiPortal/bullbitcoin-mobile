import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/payjoin/session_storage.dart';
import 'package:bb_mobile/_pkg/payjoin/sync.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payjoin_flutter/bitcoin_ffi.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/uri.dart';

class ReceiveCubit extends Cubit<ReceiveState> {
  ReceiveCubit({
    WalletBloc? walletBloc,
    required WalletAddress walletAddress,
    required WalletsStorageRepository walletsStorageRepository,
    required bool defaultPayjoin,
    required PayjoinSessionStorage payjoinSessionStorage,
    required PayjoinSync payjoinSync,
  })  : _walletsStorageRepository = walletsStorageRepository,
        _walletAddress = walletAddress,
        _payjoinSessionStorage = payjoinSessionStorage,
        _payjoinSync = payjoinSync,
        super(
          ReceiveState(
            walletBloc: walletBloc,
            oneWallet: walletBloc != null,
          ),
        ) {
    emit(
      state.copyWith(
        disablePayjoin: !defaultPayjoin,
      ),
    );
    loadAddress();
  }

  final WalletAddress _walletAddress;
  final WalletsStorageRepository _walletsStorageRepository;
  final PayjoinSessionStorage _payjoinSessionStorage;
  final PayjoinSync _payjoinSync;

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

    if (state.paymentNetwork == PaymentNetwork.lightning) {
      emit(state.copyWith(defaultAddress: null));
    }

    if (!walletBloc.state.wallet!.mainWallet) {
      emit(state.copyWith(paymentNetwork: PaymentNetwork.bitcoin));
    }

    // final watchOnly = walletBloc.state.wallet!.watchOnly();
    // if (watchOnly)
    //   emit(state.copyWith(paymentNetwork: ReceivePaymentNetwork.bitcoin));
    loadAddress();
    if (state.paymentNetwork == PaymentNetwork.bitcoin &&
        !state.disablePayjoin) {
      loadPayjoinReceiver(state.walletBloc!.state.wallet!.isTestnet());
    }
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

  Future<void> loadAddress() async {
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

    if (!isLiq && state.defaultAddress != null) {
      emit(
        state.copyWith(description: address.label ?? ''),
      );
    }

    if (isLiq && state.defaultLiquidAddress != null) {
      emit(
        state.copyWith(description: address.label ?? ''),
      );
    }
  }

  Future<void> generateNewAddress() async {
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
        // privateLabel: '',
        savedDescription: '',
        description: '',
      ),
    );
  }

  void descriptionChanged(String description) {
    emit(state.copyWith(description: description));
  }

  Future<void> saveAddrressLabel() async {
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

  void loadPayjoinReceiver(bool isTestnet) async {
    final ohttpRelay = await Url.fromStr('https://ohttp.achow101.com');
    final payjoinDirectory = await Url.fromStr('https://payjo.in');
    final ohttpKeys = await fetchOhttpKeys(
      ohttpRelay: ohttpRelay,
      payjoinDirectory: payjoinDirectory,
    );
    final address = state.defaultAddress!.address;
    final receiver = await Receiver.create(
      address: address,
      network: isTestnet ? Network.testnet : Network.bitcoin,
      directory: payjoinDirectory,
      ohttpKeys: ohttpKeys,
      ohttpRelay: ohttpRelay,
    );
    await _payjoinSessionStorage.insertReceiverSession(receiver);
    emit(state.copyWith(payjoinReceiver: receiver));
    try {
      _payjoinSync.syncPayjoin(
        receiver: receiver,
      );
    } catch (e) {
      print('error: $e');
    }
  }

  Future<String> processPayjoinProposal(
    UncheckedProposal proposal,
    bool isTestnet,
  ) async {
    final fallbackTx = await proposal.extractTxToScheduleBroadcast();
    print('fallback tx (broadcast this if payjoin fails): $fallbackTx');

    // Receive Check 1: can broadcast
    final pj1 = await proposal.assumeInteractiveReceiver();
    // Receive Check 2: original PSBT has no receiver-owned inputs
    final pj2 = await pj1.checkInputsNotOwned(
      isOwned: (inputScript) async {
        final address = await bdk.Address.fromScript(
          script: bdk.ScriptBuf(bytes: inputScript),
          network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
        );
        final wallet = state.walletBloc?.state.wallet;
        if (wallet == null) return false;
        return (wallet.getAddressFromWallet(address.toString()) != null);
      },
    );
    // Receive Check 3: sender inputs have not been seen before (prevent probing attacks)
    final pj3 = await pj2.checkNoInputsSeenBefore(
      isKnown: (input) {
        // TODO: keep track of seen inputs in hive storage?
        return false;
      },
    );

    // Identify receiver outputs
    final pj4 = await pj3.identifyReceiverOutputs(
      isReceiverOutput: (outputScript) async {
        final address = await bdk.Address.fromScript(
          script: bdk.ScriptBuf(bytes: outputScript),
          network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
        );
        final wallet = state.walletBloc?.state.wallet;
        if (wallet == null) return false;
        return (wallet.getAddressFromWallet(address.toString()) != null);
      },
    );
    final pj5 = await pj4.commitOutputs();

    // Contribute receiver inputs
    final inputs = await Future.wait(
      state.walletBloc!.state.wallet!
          .spendableUtxos()
          .map((utxo) => inputPairFromUtxo(utxo, isTestnet)),
    );
    final selected_utxo = await pj5.tryPreservingPrivacy(
      candidateInputs: inputs,
    );
    final pj6 = await pj5.contributeInputs(replacementInputs: [selected_utxo]);
    final pj7 = await pj6.commitInputs();

    // Finalize proposal
    final payjoin_proposal = await pj7.finalizeProposal(
      processPsbt: (String psbt) {
        // TODO: sign PSBT
        return psbt;
      },
      maxFeeRateSatPerVb: BigInt.zero,
    );

    final proposal_psbt = await payjoin_proposal.psbt();
    return proposal_psbt;
  }

  Future<InputPair> inputPairFromUtxo(UTXO utxo, bool isTestnet) async {
    // TODO: this seems like a roundabout way of getting the script pubkey
    final address = await bdk.Address.fromString(
      s: utxo.address.address,
      network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    );
    final spk = address.scriptPubkey().bytes;
    final psbtin = PsbtInput(
      witnessUtxo: TxOut(
        value: BigInt.from(utxo.value),
        scriptPubkey: spk,
      ),
      // TODO: redeem script/witness script?
    );
    // TODO: perhaps TxIn.default() should be exposed in payjoin_flutter api
    final txin = TxIn(
      previousOutput: OutPoint(txid: utxo.txid, vout: utxo.txIndex),
      scriptSig: await Script.newInstance(rawOutputScript: []),
      sequence: 0xFFFFFFFF,
      witness: [],
    );
    return InputPair.newInstance(txin, psbtin);
  }
}
