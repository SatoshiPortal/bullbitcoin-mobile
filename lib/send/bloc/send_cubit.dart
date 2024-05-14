import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/bip21.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/send/bloc/send_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState> {
  SendCubit({
    required Barcode barcode,
    WalletBloc? walletBloc,
    required WalletTx walletTx,
    required FileStorage fileStorage,
    required NetworkCubit networkCubit,
    required CurrencyCubit currencyCubit,
    required bool openScanner,
    required HomeCubit homeCubit,
    required bool defaultRBF,
    required SwapBoltz swapBoltz,
  })  : _homeCubit = homeCubit,
        _networkCubit = networkCubit,
        _currencyCubit = currencyCubit,
        _walletTx = walletTx,
        _fileStorage = fileStorage,
        _barcode = barcode,
        _swapBoltz = swapBoltz,
        super(
          SendState(
            selectedWalletBloc: walletBloc,
          ),
        ) {
    emit(
      state.copyWith(
        disableRBF: !defaultRBF,
        // selectedWalletBloc: walletBloc,
      ),
    );

    if (openScanner) scanAddress();
  }

  final Barcode _barcode;
  final FileStorage _fileStorage;
  final WalletTx _walletTx;
  final SwapBoltz _swapBoltz;

  final NetworkCubit _networkCubit;
  final CurrencyCubit _currencyCubit;
  final HomeCubit _homeCubit;

  void updateAddress(String? addr) async {
    resetWalletSelection();
    resetErrors();
    emit(
      state.copyWith(
        errScanningAddress: '',
        scanningAddress: true,
        paymentNetwork: null,
      ),
    );
    final address = addr ?? state.address;
    final (paymentNetwork, err) = state.getPaymentNetwork(address);
    if (err != null) {
      emit(
        state.copyWith(
          errScanningAddress: err.toString(),
          scanningAddress: false,
          address: '',
          invoice: null,
          note: '',
        ),
      );
      _currencyCubit.updateAmountDirect(0);
      _currencyCubit.updateAmount('');
      resetWalletSelection();
      if (address.isEmpty) resetErrors();
      return;
    }

    emit(state.copyWith(paymentNetwork: paymentNetwork));

    switch (paymentNetwork!) {
      case AddressNetwork.bip21Bitcoin:
        final bip21Obj = bip21.decode(address);
        final newAddress = bip21Obj.address;
        emit(state.copyWith(address: newAddress));
        final amount = bip21Obj.options['amount'] as num?;
        if (amount != null) {
          _currencyCubit.btcToCurrentTempAmount(amount.toDouble());
          final amountInSats = (amount * 100000000).toInt();
          _currencyCubit.updateAmountDirect(amountInSats);
          emit(state.copyWith(tempAmt: amountInSats));
        }
        final label = bip21Obj.options['label'] as String?;
        if (label != null) {
          emit(state.copyWith(note: label));
        }
      case AddressNetwork.bip21Liquid:
        final bip21Obj = bip21.decode(
          address.startsWith('liquidnetwork:')
              ? address.replaceFirst('liquidnetwork:', 'bitcoin:')
              : address.replaceFirst('liquidtestnet:', 'bitcoin:'),
        );
        final newAddress = bip21Obj.address;
        emit(state.copyWith(address: newAddress));
        final amount = bip21Obj.options['amount'] as num?;
        if (amount != null) {
          _currencyCubit.btcToCurrentTempAmount(amount.toDouble());
          final amountInSats = (amount * 100000000).toInt();
          _currencyCubit.updateAmountDirect(amountInSats);
          emit(state.copyWith(tempAmt: amountInSats));
        }
        final label = bip21Obj.options['label'] as String?;
        if (label != null) {
          emit(state.copyWith(note: label));
        }
      case AddressNetwork.lightning:
        final boltzUrl =
            _networkCubit.state.testnet ? boltzTestnetV2 : boltzMainnetV2;
        final (inv, errInv) = await _swapBoltz.decodeInvoice(
          invoice: address.toLowerCase(),
          boltzUrl: boltzUrl,
        );
        if (errInv != null) {
          emit(state.copyWith(errScanningAddress: errInv.toString()));
          return;
        }
        if (inv!.bip21 != null) {
          updateAddress(inv.bip21);
          return;
        }
        if (inv.getAmount() == 0) {
          emit(
            state.copyWith(
              errScanningAddress: 'Invoice must have an amount.',
            ),
          );
          return;
        }
        if (_networkCubit.state.testnet != inv.isTestnet()) {
          emit(state.copyWith(errScanningAddress: 'Network mismatch'));
          return;
        }
        _currencyCubit.updateAmountDirect(inv.getAmount());
        emit(state.copyWith(invoice: inv, address: address));

      case AddressNetwork.bip21Lightning:
        final invoice = address.replaceAll('lightning:', '');
        final (inv, errInv) = await _swapBoltz.decodeInvoice(invoice: invoice);
        if (errInv != null) {
          emit(state.copyWith(errScanningAddress: errInv.toString()));
          return;
        }
        if (inv!.getAmount() == 0) {
          emit(
            state.copyWith(
              errScanningAddress: 'Invoice must have an amount.',
              invoice: inv,
              address: invoice,
            ),
          );
          return;
        }
        if (_networkCubit.state.testnet != inv.isTestnet()) {
          emit(state.copyWith(errScanningAddress: 'Network mismatch'));

          return;
        }
        _currencyCubit.updateAmountDirect(inv.getAmount());
        emit(state.copyWith(invoice: inv, address: invoice));

      case AddressNetwork.bitcoin:
        emit(state.copyWith(address: address));

      case AddressNetwork.liquid:
        emit(state.copyWith(address: address));
    }

    emit(state.copyWith(scanningAddress: false));
    selectWallets();
  }

  void selectWallets() {
    resetErrors();
    if (state.paymentNetwork == null) return;
    switch (state.paymentNetwork!) {
      case AddressNetwork.bip21Bitcoin:
        _processBitcoinAddress();
      case AddressNetwork.bip21Liquid:
        _processLiquidAddress();
      case AddressNetwork.lightning:
        _processLnInvoice();
      case AddressNetwork.bitcoin:
        _processBitcoinAddress();
      case AddressNetwork.liquid:
        _processLiquidAddress();
      case AddressNetwork.bip21Lightning:
        _processLnInvoice();
    }
  }

  Future _processLnInvoice() async {
    final amt = state.invoice!.getAmount();
    final wallets = _homeCubit.state.walletsWithEnoughBalance(
      amt,
      _networkCubit.state.getBBNetwork(),
      // onlyMain: true,
    );
    if (wallets.isEmpty) {
      emit(
        state.copyWith(
          errScanningAddress: 'No wallet with enough balance',
        ),
      );
      resetWalletSelection(clearInv: false);
      return;
    }

    final selectWallet = state.selectLiqThenSecThenOtherBtc(wallets);
    emit(
      state.copyWith(
        selectedWalletBloc: selectWallet,
        enabledWallets: wallets.map((_) => _.state.wallet!.id).toList(),
      ),
    );

    if (amt == 0)
      emit(state.copyWith(showSendButton: false));
    else
      emit(state.copyWith(showSendButton: true));
  }

  Future _processBitcoinAddress() async {
    final amount = _currencyCubit.state.amount;
    final wallets = _homeCubit.state.walletsWithEnoughBalance(
      amount,
      _networkCubit.state.getBBNetwork(),
      onlyBitcoin: true,
    );
    if (wallets.isEmpty) {
      emit(
        state.copyWith(
          errScanningAddress: 'No wallet with enough balance',
        ),
      );
      resetWalletSelection();
      return;
    }

    final selectWallet = state.selectMainBtcThenOtherHighestBalBtc(wallets);

    emit(
      state.copyWith(
        enabledWallets: wallets.map((_) => _.state.wallet!.id).toList(),
        selectedWalletBloc: selectWallet,
      ),
    );

    if (amount == 0)
      emit(state.copyWith(showSendButton: false));
    else
      emit(state.copyWith(showSendButton: true));
  }

  Future _processLiquidAddress() async {
    final amount = _currencyCubit.state.amount;
    final wallets = _homeCubit.state.walletsWithEnoughBalance(
      amount,
      _networkCubit.state.getBBNetwork(),
      onlyLiquid: true,
    );
    if (wallets.isEmpty) {
      emit(
        state.copyWith(
          errScanningAddress: 'No wallet with enough balance',
        ),
      );
      resetWalletSelection();
      return;
    }

    emit(
      state.copyWith(
        selectedWalletBloc: wallets.first,
        enabledWallets: wallets.map((_) => _.state.wallet!.id).toList(),
      ),
    );

    if (amount == 0)
      emit(state.copyWith(showSendButton: false));
    else
      emit(state.copyWith(showSendButton: true));
  }

  void resetWalletSelection({bool clearInv = true}) => emit(
        state.copyWith(
          enabledWallets: [],
          selectedWalletBloc: null,
          showSendButton: false,
          invoice: clearInv ? null : state.invoice,
          tempAmt: 0,
        ),
      );

  void resetErrors() => emit(
        state.copyWith(
          errScanningAddress: '',
          errSending: '',
          errDownloadingFile: '',
        ),
      );

  void updateWalletBloc(WalletBloc walletBloc) {
    emit(state.copyWith(selectedWalletBloc: walletBloc));
  }

  void disabledDropdownClicked() {
    emit(
      state.copyWith(
        errSending:
            'Please enter payment destination and amount before selecting a wallet. We will select the best wallet for this transaction. You can override the wallet choice after.',
      ),
    );
  }

  void scanAddress() async {
    emit(state.copyWith(scanningAddress: true));
    final (address, err) = await _barcode.scan();
    if (err != null) {
      emit(
        state.copyWith(
          errScanningAddress: err.toString(),
          scanningAddress: false,
        ),
      );
      return;
    }

    updateAddress(address);
    emit(
      state.copyWith(
        scanningAddress: false,
      ),
    );
  }

  void updateAddressError(String err) =>
      emit(state.copyWith(errScanningAddress: err));

  void updateNote(String note) => emit(state.copyWith(note: note));

  void disableRBF(bool disable) => emit(state.copyWith(disableRBF: disable));

  void sendAllCoin(bool sendAll) {
    if (state.selectedWalletBloc == null) return;
    final balance = state.selectedWalletBloc!.state.balanceSats();
    emit(
      state.copyWith(
        sendAllCoin: sendAll,
      ),
    );
    _currencyCubit.updateAmountDirect(sendAll ? balance : 0);
  }

  void utxoSelected(UTXO utxo) {
    var selectedUtxos = state.selectedUtxos.toList();

    if (selectedUtxos.containsUtxo(utxo))
      selectedUtxos = selectedUtxos.removeUtxo(utxo);
    else
      selectedUtxos.add(utxo);

    emit(state.copyWith(selectedUtxos: selectedUtxos));
  }

  void clearSelectedUtxos() {
    emit(state.copyWith(selectedUtxos: []));
  }

  void downloadPSBTClicked() async {
    emit(
      state.copyWith(
        downloadingFile: true,
        errDownloadingFile: '',
        downloaded: false,
      ),
    );
    final psbt = state.psbt;
    if (psbt.isEmpty) {
      emit(
        state.copyWith(
          downloadingFile: false,
          errDownloadingFile: 'No PSBT',
        ),
      );
      return;
    }
    final txid = state.tx?.txid;
    if (txid == null) {
      emit(
        state.copyWith(
          downloadingFile: false,
          errDownloadingFile: 'No TXID',
        ),
      );
      return;
    }

    final errSave = await _fileStorage.savePSBT(
      psbt: psbt,
      txid: txid,
    );

    if (errSave != null) {
      emit(
        state.copyWith(
          downloadingFile: false,
          errDownloadingFile: errSave.toString(),
        ),
      );
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    emit(state.copyWith(downloadingFile: false, downloaded: true));
  }

  void buildTxFromSwap({
    required int networkFees,
    required SwapTx swaptx,
  }) async {
    if (state.sending) return;
    if (state.selectedWalletBloc == null) return;
    final w = state.selectedWalletBloc!.state.wallet;

    final localWalletBloc = _homeCubit.state.getWalletBlocById(w!.id);
    if (localWalletBloc == null) return;
    final localWallet = localWalletBloc.state.wallet;

    if (!localWallet!.mainWallet) return;

    final address = swaptx.scriptAddress;
    final fee = networkFees;

    // emit(state.copyWith(sending: true, errSending: ''));

    final (buildResp, err) = await _walletTx.buildTx(
      wallet: localWallet,
      isManualSend: false,
      address: address,
      amount: swaptx.outAmount,
      sendAllCoin: false,
      feeRate: localWallet.isLiquid() ? 0.1 : fee.toDouble(),
      enableRbf: false,
      note: state.note,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errSending: err.toString(),
          sending: false,
        ),
      );
      return;
    }

    final (_, tx, feeAmt) = buildResp!;

    emit(
      state.copyWith(
        psbtSigned: tx!.psbt,
        psbtSignedFeeAmount: feeAmt,
        tx: tx,
        signed: true,
        sending: false,
      ),
    );
  }

  // -----------------
  void sendSwapClicked() async {
    emit(state.copyWith(sending: true, errSending: ''));

    final tx = state.tx!;
    final swap = state.tx!.swapTx!;
    final w = state.selectedWalletBloc!.state.wallet;

    final localWalletBloc = _homeCubit.state.getWalletBlocById(w!.id);
    if (localWalletBloc == null) return;
    final wallet = localWalletBloc.state.wallet;

    if (!wallet!.mainWallet) return;

    final (wtxid, errBroadcast) = await _walletTx.broadcastTxWithWallet(
      wallet: wallet,
      address: swap.scriptAddress,
      note: state.note,
      transaction: tx.copyWith(
        swapTx: swap,
        isSwap: true,
      ),
    );
    if (errBroadcast != null) {
      emit(state.copyWith(errSending: errBroadcast.toString(), sending: false));
      return;
    }

    final txWithId = tx.copyWith(txid: wtxid?.$2 ?? '');
    emit(state.copyWith(tx: txWithId));

    final (updatedWallet, _) = wtxid!;

    state.selectedWalletBloc!.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [
          UpdateWalletTypes.addresses,
          UpdateWalletTypes.transactions,
          UpdateWalletTypes.swaps,
        ],
      ),
    );
    // }
    Future.delayed(50.ms);
    state.selectedWalletBloc!.add(SyncWallet());

    emit(state.copyWith(sending: false, sent: true));
  }

  void confirmClickedd({required int networkFees}) async {
    if (state.sending) return;
    if (state.selectedWalletBloc == null) return;

    final address = state.address;
    final fee = networkFees;

    final bool enableRbf;

    enableRbf = !state.disableRBF;

    emit(state.copyWith(sending: true, errSending: ''));

    final localWallet = state.selectedWalletBloc!.state.wallet;

    final (buildResp, err) = await _walletTx.buildTx(
      wallet: localWallet!,
      isManualSend: state.selectedUtxos.isNotEmpty,
      address: address,
      amount: _currencyCubit.state.amount,
      sendAllCoin: state.sendAllCoin,
      feeRate: localWallet.baseWalletType == BaseWalletType.Liquid
          ? 0.1
          : fee.toDouble(),
      enableRbf: enableRbf,
      selectedUtxos: state.selectedUtxos,
      note: state.note,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errSending: err.toString(),
          sending: false,
        ),
      );
      return;
    }

    final (wallet, tx, feeAmt) = buildResp!;

    if (wallet!.type == BBWalletType.secure ||
        wallet.type == BBWalletType.words ||
        wallet.type == BBWalletType.instant) {
      emit(
        state.copyWith(
          sending: false,
          psbtSigned: tx!.psbt,
          psbtSignedFeeAmount: feeAmt,
          tx: tx,
          signed: true,
        ),
      );
      // if (swaptx != null) sendClicked(swaptx: swaptx);

      return;
    }

    state.selectedWalletBloc!.add(
      UpdateWallet(
        wallet,
        updateTypes: [
          UpdateWalletTypes.transactions,
          UpdateWalletTypes.swaps,
        ],
      ),
    );

    emit(
      state.copyWith(
        sending: false,
        psbt: tx!.psbt!,
        tx: tx,
      ),
    );
  }

  void sendClicked() async {
    if (state.selectedWalletBloc == null) return;
    emit(state.copyWith(sending: true, errSending: ''));
    final address = state.address;
    final (wtxid, err) = await _walletTx.broadcastTxWithWallet(
      wallet: state.selectedWalletBloc!.state.wallet!,
      address: address,
      note: state.note,
      transaction: state.tx!,
      // .copyWith(
      //   swapTx: swaptx,
      //   isSwap: swaptx != null,
      // ),
    );
    if (err != null) {
      emit(state.copyWith(errSending: err.toString(), sending: false));
      return;
    }

    final txWithId = state.tx?.copyWith(txid: wtxid?.$2 ?? '');
    emit(state.copyWith(tx: txWithId));

    final (wallet, _) = wtxid!;

    // if (swaptx != null) {
    //   final (updatedWalletWithTxid, err2) = await _walletTx.addSwapTxToWallet(
    //     wallet: wallet,
    //     swapTx: swaptx.copyWith(txid: txid),
    //   );

    //   if (err2 != null) {
    //     emit(state.copyWith(errSending: err.toString()));
    //     return;
    //   }

    //   state.selectedWalletBloc!.add(
    //     UpdateWallet(
    //       updatedWalletWithTxid,
    //       updateTypes: [
    //         UpdateWalletTypes.addresses,
    //         UpdateWalletTypes.transactions,
    //         UpdateWalletTypes.swaps,
    //       ],
    //     ),
    //   );
    // } else {
    state.selectedWalletBloc!.add(
      UpdateWallet(
        wallet,
        updateTypes: [
          UpdateWalletTypes.addresses,
          UpdateWalletTypes.transactions,
          UpdateWalletTypes.swaps,
        ],
      ),
    );
    // }
    Future.delayed(50.ms);
    state.selectedWalletBloc!.add(SyncWallet());

    emit(state.copyWith(sending: false, sent: true));
  }

  void txSettled() {
    if (state.tx == null) return;
    emit(state.copyWith(txSettled: true));
  }

  void dispose() {
    super.close();
  }
}

// bolt 11 testnet
//lntb11110n1pnrc620pp5mpdwk98cl7wnj9mwc69wf7v8t7fadt2n4rx22g8rzf2y48l8m4esdpz2djkuepqw3hjqnpdgf2yxgrpv3j8yetnwvcqz95xqyp2xqsp5vwyhphcdvhc399ffqqsphp4xzjg569rchzkh9kte048hajxu2hns9qyyssqqy24765myh9ew4zklqx8qhycg9g4rn7w56t75vhfqk9a2sjpedsp4t90ms20ufckmc0fgjrhvfxcrdmhv5780wmezl7ps2djcuqtnhsp07jm9w


// BIP21 URI with On-chain address
// bitcoin:BC1QYLH3U67J673H6Y6ALV70M0PL2YZ53TZHVXGG7U?amount=0.00001&label=sbddesign%3A%20For%20lunch%20Tuesday&message=For%20lunch%20Tuesday

// BIP21 URI with BOLT 11 invoice
// bitcoin:BC1QYLH3U67J673H6Y6ALV70M0PL2YZ53TZHVXGG7U?amount=0.00001&label=sbddesign%3A%20For%20lunch%20Tuesday&message=For%20lunch%20Tuesday&lightning=LNBC10U1P3PJ257PP5YZTKWJCZ5FTL5LAXKAV23ZMZEKAW37ZK6KMV80PK4XAEV5QHTZ7QDPDWD3XGER9WD5KWM36YPRX7U3QD36KUCMGYP282ETNV3SHJCQZPGXQYZ5VQSP5USYC4LK9CHSFP53KVCNVQ456GANH60D89REYKDNGSMTJ6YW3NHVQ9QYYSSQJCEWM5CJWZ4A6RFJX77C490YCED6PEMK0UPKXHY89CMM7SCT66K8GNEANWYKZGDRWRFJE69H9U5U0W57RRCSYSAS7GADWMZXC8C6T0SPJAZUP6

// BIP21 URI with BOLT 12 offer
// bitcoin:BC1QYLH3U67J673H6Y6ALV70M0PL2YZ53TZHVXGG7U?amount=0.00021&label=sbddesign%3A%20For%20lunch%20Tuesday&message=For%20lunch%20Tuesday&lightning=LNO1PG257ENXV4EZQCNEYPE82UM50YNHXGRWDAJX283QFWDPL28QQMC78YMLVHMXCSYWDK5WRJNJ36JRYG488QWLRNZYJCZS

// BOLT 11 Invoice mainnet
// LNBC10U1P3PJ257PP5YZTKWJCZ5FTL5LAXKAV23ZMZEKAW37ZK6KMV80PK4XAEV5QHTZ7QDPDWD3XGER9WD5KWM36YPRX7U3QD36KUCMGYP282ETNV3SHJCQZPGXQYZ5VQSP5USYC4LK9CHSFP53KVCNVQ456GANH60D89REYKDNGSMTJ6YW3NHVQ9QYYSSQJCEWM5CJWZ4A6RFJX77C490YCED6PEMK0UPKXHY89CMM7SCT66K8GNEANWYKZGDRWRFJE69H9U5U0W57RRCSYSAS7GADWMZXC8C6T0SPJAZUP6


// 6000 sats
// lnbc60u1pnre9sysp5luy79ufxhywcnage3eswwra6tuk62x4x9p9djgyd5x2jy54gmpmspp5chhrwxtceu20k9nhlsy8zhzwsxht79lvfatu20eegjzmxljrlz8sdpz2djkuepqw3hjqnpdgf2yxgrpv3j8yetnwvxqyp2xqcqz959qxpqysgq8zseyvltvj5ny698mkg20pzccuqk9dpt5stues0jcc4hhdxe8ehrm3x7md52w493udwvz3yastu9ht4zvuykupmdaclf7323djl0mdsp2h2rmx

// 1234 sats
// lnbc12340n1pnretv7sp5d87xcykdvf03adm2au86ssury8fggz3jra5af3pmya0ftn32pjhqpp5ekmafv4q72f25d0varnp5h0cmqpqkjv20t9klcj9vaevp7dxd5cqdpz2djkuepqw3hjqnpdgf2yxgrpv3j8yetnwvxqyp2xqcqz959qxpqysgq2357qtv82qgpdttzn82hsnyha3tfgvgldc0fc8nrf7qxaxq0yt79fsehc3wprjld7hqwdeau4ct6fl6gxq99gvaulqthhludgqzmxrgpk4zw6n

// 1234 testnet 
// lntb12340n1pnrevr8pp57e8n6mqr8zwajjpe4r7nxsy0v4aql2h3edfdyjerda4neghj564qdpz2djkuepqw3hjqnpdgf2yxgrpv3j8yetnwvcqz95xqyp2xqsp52m4ue6g3r56xfeac69e95ewvhnrna8upv25kd97890v8czdyvfnq9qyyssq4g2efr6ck9d8ylyzuv5ahudxfr4zh30p3c5g00xmmkpqex2c08vjlhtjqr7h5lpc04v0e84hav52um4ak2q94zuncxm0vs222pu733gpa6y7fa
