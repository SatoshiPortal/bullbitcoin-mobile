import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/bip21.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/network_fees_cubit.dart';
import 'package:bb_mobile/send/bloc/state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState> {
  SendCubit({
    required this.barcode,
    required this.walletBloc,
    required this.settingsCubit,
    required this.bullBitcoinAPI,
    required this.hiveStorage,
    required this.secureStorage,
    required this.walletAddress,
    required this.walletTx,
    required this.walletSensTx,
    required this.walletRepository,
    required this.walletSensRepository,
    required this.walletCreate,
    required this.walletSensCreate,
    required this.mempoolAPI,
    required this.fileStorage,
    required this.networkCubit,
    required this.networkFeesCubit,
    required this.currencyCubit,
  }) : super(const SendState()) {
    emit(state.copyWith(disableRBF: !settingsCubit.state.defaultRBF));
  }

  final Barcode barcode;
  final WalletBloc walletBloc;
  final SettingsCubit settingsCubit;
  final BullBitcoinAPI bullBitcoinAPI;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletAddress walletAddress;
  final WalletTx walletTx;
  final WalletSensitiveTx walletSensTx;
  final WalletRepository walletRepository;
  final WalletSensitiveRepository walletSensRepository;
  final WalletCreate walletCreate;
  final NetworkCubit networkCubit;
  final NetworkFeesCubit networkFeesCubit;
  final CurrencyCubit currencyCubit;

  final WalletSensitiveCreate walletSensCreate;
  final MempoolAPI mempoolAPI;
  final FileStorage fileStorage;

  void loadAddressesAndBalances() {
    walletBloc.add(GetAddresses());
  }

  void updateAddress(String address) {
    try {
      if (address.startsWith('bitcoin')) {
        final bip21Obj = bip21.decode(address);
        final newAddress = bip21Obj.address;
        emit(state.copyWith(address: newAddress));
        final amount = bip21Obj.options['amount'] as num?;
        if (amount != null) {
          currencyCubit.btcToCurrentTempAmount(amount.toDouble());
          final amountInSats = (amount * 100000000).toInt();

          currencyCubit.updateAmountDirect(amountInSats);
        }
        final label = bip21Obj.options['label'] as String?;
        if (label != null) {
          emit(state.copyWith(note: label));
        }
      } else
        emit(state.copyWith(address: address));
    } catch (e) {
      emit(
        state.copyWith(
          address: '',
          note: '',
          errScanningAddress: e.toString(),
        ),
      );
      currencyCubit.updateAmountDirect(0);
    }
  }

  void scanAddress() async {
    emit(state.copyWith(scanningAddress: true));
    final (address, err) = await barcode.scan();
    if (err != null) {
      emit(
        state.copyWith(
          errScanningAddress: err.toString(),
          scanningAddress: false,
        ),
      );
      return;
    }

    updateAddress(address!);
    emit(
      state.copyWith(
        scanningAddress: false,
      ),
    );
  }

  void updateNote(String note) {
    emit(state.copyWith(note: note));
  }

  void disableRBF(bool disable) {
    emit(state.copyWith(disableRBF: disable));
  }

  void sendAllCoin(bool sendAll) {
    final balance = walletBloc.state.balanceSats();
    emit(
      state.copyWith(
        sendAllCoin: sendAll,
      ),
    );
    currencyCubit.updateAmountDirect(sendAll ? balance : 0);
    _updateShowSend();
  }

  void utxoAddressSelected(Address address) {
    final selectedAddresses = state.selectedAddresses.toList();
    if (selectedAddresses.contains(address))
      selectedAddresses.remove(address);
    else
      selectedAddresses.add(address);

    emit(state.copyWith(selectedAddresses: selectedAddresses));

    _updateShowSend();
  }

  void clearSelectedUTXOAddresses() {
    emit(state.copyWith(selectedAddresses: []));
  }

  void _updateShowSend() {
    final amount = currencyCubit.state.amount;
    if (amount == 0) {
      emit(state.copyWith(showSendButton: false));
      return;
    }
    if (state.selectedAddresses.isEmpty) {
      if (amount > 0 && walletBloc.state.balanceSats() >= amount)
        emit(state.copyWith(showSendButton: true));
      else
        emit(state.copyWith(showSendButton: false));
    } else {
      final hasEnoughCoinns = state.selectedAddressesHasEnoughCoins(amount);
      emit(state.copyWith(showSendButton: hasEnoughCoinns));
    }
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
      emit(state.copyWith(downloadingFile: false, errDownloadingFile: 'No PSBT'));
      return;
    }
    final txid = state.tx?.txid;
    if (txid == null) {
      emit(state.copyWith(downloadingFile: false, errDownloadingFile: 'No TXID'));
      return;
    }

    final errSave = await fileStorage.savePSBT(
      psbt: psbt,
      txid: txid,
    );

    if (errSave != null) {
      emit(state.copyWith(downloadingFile: false, errDownloadingFile: errSave.toString()));
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    emit(state.copyWith(downloadingFile: false, downloaded: true));
  }

  void confirmClickedd() async {
    if (state.sending) return;
    final bdkWallet = walletBloc.state.bdkWallet;
    if (bdkWallet == null) return;

    emit(state.copyWith(sending: true, errSending: ''));

    final localWallet = walletBloc.state.wallet;

    final (buildResp, err) = await walletTx.buildTx(
      wallet: localWallet!,
      pubWallet: walletBloc.state.bdkWallet!,
      isManualSend: state.selectedAddresses.isNotEmpty,
      address: state.address,
      amount: currencyCubit.state.amount,
      sendAllCoin: state.sendAllCoin,
      feeRate: networkFeesCubit.state.selectedFeesOption == 4
          ? networkFeesCubit.state.fees!.toDouble()
          : networkFeesCubit.state.feesList![networkFeesCubit.state.selectedFeesOption].toDouble(),
      enableRbf: !state.disableRBF,
      selectedAddresses: state.selectedAddresses,
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

    final (tx, feeAmt, psbt) = buildResp!;

    if (localWallet.type == BBWalletType.newSeed || localWallet.type == BBWalletType.words) {
      final (seed, sErr) = await walletSensRepository.readSeed(
        fingerprintIndex: walletBloc.state.wallet!.getRelatedSeedStorageString(),
        secureStore: secureStorage,
      );

      if (sErr != null) {
        emit(
          state.copyWith(errSending: sErr.toString()),
        );
        return;
      }
      final (bdkSignerWallet, errr) =
          await walletSensCreate.loadPrivateBdkWallet(localWallet, seed!);
      if (errr != null) {
        emit(state.copyWith(errSending: errr.toString(), signed: false));
        return;
      }
      final (signed, sErrr) =
          await walletSensTx.signTx(unsignedPSBT: psbt, signingWallet: bdkSignerWallet!);
      if (sErrr != null) {
        emit(state.copyWith(errSending: sErrr.toString(), signed: false));
        return;
      }

      emit(
        state.copyWith(
          sending: false,
          psbtSigned: signed,
          psbtSignedFeeAmount: feeAmt,
          tx: tx,
          signed: true,
        ),
      );
    } else {
      final txs = localWallet.transactions.toList();
      txs.add(tx!);

      final (w, _) = await walletTx.addUnsignedTxToWallet(transaction: tx, wallet: localWallet);
      walletBloc.add(UpdateWallet(w, updateTypes: [UpdateWalletTypes.transactions]));
      await Future.delayed(const Duration(seconds: 1));

      emit(
        state.copyWith(
          sending: false,
          psbt: psbt,
          tx: tx,
        ),
      );
    }
  }

  void sendClicked() async {
    emit(state.copyWith(sending: true, errSending: ''));

    final (wtxid, err) = await walletTx.broadcastTxWithWallet(
      psbt: state.psbtSigned!,
      blockchain: networkCubit.state.blockchain!,
      wallet: walletBloc.state.wallet!,
      address: state.address,
      note: state.note,
      transaction: state.tx!,
    );
    if (err != null) {
      emit(state.copyWith(errSending: err.toString(), sending: false));
      return;
    }

    final (wallet, txid) = wtxid!;

    final (_, updatedWallet) = await walletAddress.addAddressToWallet(
      address: (null, state.address),
      wallet: wallet,
      label: state.note,
      spentTxId: txid,
      kind: AddressKind.external,
      state: AddressStatus.used,
    );

    walletBloc.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [
          UpdateWalletTypes.addresses,
          UpdateWalletTypes.transactions,
        ],
      ),
    );
    walletBloc.add(SyncWallet());

    emit(state.copyWith(sending: false, sent: true));
  }
}
