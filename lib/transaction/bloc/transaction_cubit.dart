import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/network_fees_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/transaction/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionCubit extends Cubit<TransactionState> {
  TransactionCubit({
    required Transaction tx,
    required this.walletBloc,
    required this.hiveStorage,
    required this.secureStorage,
    required this.walletTx,
    required this.walletSensTx,
    required this.walletRepository,
    required this.walletSensRepository,
    required this.walletAddress,
    required this.walletSync,
    required this.walletCreate,
    required this.walletSensCreate,
    required this.walletUpdate,
    required this.mempoolAPI,
    required this.settingsCubit,
    required this.networkCubit,
    required this.networkFeesCubit,
  }) : super(TransactionState(tx: tx)) {
    if (tx.isReceived())
      loadReceiveLabel();
    else
      loadSentLabel();

    loadTx();
  }

  final WalletBloc walletBloc;
  final MempoolAPI mempoolAPI;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletTx walletTx;
  final WalletSensitiveTx walletSensTx;
  final WalletUpdate walletUpdate;

  final WalletRepository walletRepository;

  final WalletSensitiveRepository walletSensRepository;
  final WalletAddress walletAddress;

  final WalletSync walletSync;
  final WalletCreate walletCreate;

  final WalletSensitiveCreate walletSensCreate;
  final SettingsCubit settingsCubit;
  final NetworkCubit networkCubit;
  final NetworkFeesCubit networkFeesCubit;

  void loadTx() async {
    emit(state.copyWith(loadingAddresses: true, errLoadingAddresses: ''));

    Future.wait([
      // loadInAddresses(),
      // loadOutAddresses(),
    ]);

    emit(state.copyWith(loadingAddresses: false));
  }

  // Future loadInAddresses() async {
  //   final (tx, err) = await walletTx.updateTxInputAddresses(
  //     tx: state.tx,
  //     wallet: walletBloc.state.wallet!,
  //     mempoolAPI: mempoolAPI,
  //   );
  //   if (err != null) {
  //     emit(
  //       state.copyWith(
  //         errLoadingAddresses: err.toString(),
  //       ),
  //     );
  //     return;
  //   }

  //   emit(state.copyWith(tx: tx!));
  // }

  // Future loadOutAddresses() async {
  //   final (tx, err) = await walletTx.updateTxOutputAddresses(
  //     tx: state.tx,
  //     wallet: walletBloc.state.wallet!,
  //   );
  //   if (err != null) {
  //     emit(
  //       state.copyWith(
  //         errLoadingAddresses: err.toString(),
  //       ),
  //     );
  //     return;
  //   }
  //   emit(state.copyWith(tx: tx!));
  // }

  void loadReceiveLabel() {
    final tx = state.tx;
    final txid = tx.txid;

    final address = walletBloc.state.wallet!.getAddressFromAddresses(txid);

    if (address == null || address.label == null) return;

    emit(
      state.copyWith(
        tx: tx.copyWith(label: address.label),
        label: address.label!,
      ),
    );
  }

  void loadSentLabel() {}

  // void loadLabel() async {
  //   final tx = (walletBloc.state.wallet?.transactions ?? []).firstWhere(
  //     (t) => t.txid == state.tx.txid,
  //     orElse: () => state.tx,
  //   );
  //   emit(state.copyWith(label: tx.label ?? ''));
  // }

  void labelChanged(String label) {
    emit(state.copyWith(label: label));
  }

  void saveLabelClicked() async {
    final label = state.tx.label;
    if (label == state.label) return;
    emit(state.copyWith(savingLabel: true, errSavingLabel: ''));

    final tx = state.tx.copyWith(
      label: state.label,
      outAddrs: state.tx.outAddrs
          .map(
            (out) => out.copyWith(
              label: out.label ?? label,
            ),
          )
          .toList(),
    );

    final updateWallet = walletBloc.state.wallet!.copyWith(
      transactions: [
        for (final t in walletBloc.state.wallet?.transactions ?? <Transaction>[])
          if (t.txid == tx.txid) tx else t,
      ],
    );

    final (w, err) = await walletUpdate.updateAddressesFromTxs(updateWallet);
    if (err != null) {
      emit(state.copyWith(errSavingLabel: err.toString(), savingLabel: false));
      return;
    }

    walletBloc.add(
      UpdateWallet(
        w!,
        updateTypes: [UpdateWalletTypes.transactions, UpdateWalletTypes.addresses],
      ),
    );

    await Future.delayed(const Duration(seconds: 1));
    walletBloc.add(ListTransactions());

    emit(
      state.copyWith(
        savingLabel: false,
        tx: tx,
      ),
    );
  }

  // void updateFeeRate(String feeRate) {
  //   final amt = int.tryParse(feeRate) ?? 0;
  //   emit(state.copyWith(feeRate: amt));
  // }

  // void updateFeeRateInt(int feeRate) {
  //   emit(state.copyWith(feeRate: feeRate));
  // }

  // SENSITIVE FX
  void buildTx() async {
    emit(state.copyWith(buildingTx: true, errBuildingTx: ''));

    final isManualFees = networkFeesCubit.state.feeOption() == 4;
    int fees = 0;
    if (!isManualFees)
      fees = networkFeesCubit.state.feesList?[networkFeesCubit.state.feeOption()] ?? 0;
    else
      fees = networkFeesCubit.state.fee();

    if (fees == 0) {
      emit(
        state.copyWith(
          buildingTx: false,
          errBuildingTx: 'Fee rate must be greater than 0',
        ),
      );
      return;
    }

    final (wallet, err) = await walletRepository.readWallet(
      walletHashId: walletBloc.state.wallet!.getWalletStorageString(),
      hiveStore: hiveStorage,
    );
    if (err != null) {
      emit(state.copyWith(errBuildingTx: err.toString(), buildingTx: false));
      return;
    }

    final (seed, sErr) = await walletSensRepository.readSeed(
      fingerprintIndex: walletBloc.state.wallet!.getRelatedSeedStorageString(),
      secureStore: SecureStorage(),
    );

    if (sErr != null) {
      emit(state.copyWith(errBuildingTx: err.toString(), buildingTx: false));
      return;
    }

    final (bdkSignerWallet, errr) = await walletSensCreate.loadPrivateBdkWallet(wallet!, seed!);
    if (errr != null) {
      emit(state.copyWith(errBuildingTx: errr.toString(), buildingTx: false));
      return;
    }

    final (newTx, errrr) = await walletSensTx.buildBumpFeeTx(
      tx: state.tx,
      feeRate: fees.toDouble(),
      signingWallet: bdkSignerWallet!,
      pubWallet: walletBloc.state.bdkWallet!,
    );
    if (errrr != null) {
      // Handle Tx confirmation
      final bdkTxList = await walletBloc.state.bdkWallet?.listTransactions(true);
      if (bdkTxList != null) {
        for (final bdkTx in bdkTxList) {
          if (bdkTx.txid == state.tx.txid && bdkTx.confirmationTime?.height != 0) {
            emit(
              state.copyWith(
                buildingTx: false,
                errBuildingTx:
                    'Transaction got confirmed in block ${bdkTx.confirmationTime?.height}. Cannot bump',
              ),
            );
            return;
          }
        }
      }
      emit(
        state.copyWith(
          buildingTx: false,
          errBuildingTx: errrr.toString(),
        ),
      );
      return;
    }

    if (state.tx.fee! >= newTx!.fee!) {
      emit(
        state.copyWith(
          buildingTx: false,
          errBuildingTx: 'Fee rate much be higher than current fee rate',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        // buildingTx: false,
        updatedTx: newTx,
      ),
    );
    await Future.delayed(200.ms);
    sendTx();
  }

  void sendTx() async {
    emit(state.copyWith(sendingTx: true, errSendingTx: '', buildingTx: false));
    final tx = state.updatedTx!;
    final wallet = walletBloc.state.wallet!;
    final blockchain = networkCubit.state.blockchain!;
    final (wtxid, err) = await walletTx.broadcastTxWithWallet(
      psbt: tx.psbt!,
      address: tx.toAddress!,
      wallet: wallet,
      blockchain: blockchain,
      transaction: tx,
    );
    if (err != null) {
      emit(
        state.copyWith(
          sendingTx: false,
          errSendingTx: err.toString(),
        ),
      );
      return;
    }

    final (w, txid) = wtxid!;

    final (_, updatedWallet) = await walletAddress.addAddressToWallet(
      address: (null, tx.toAddress!),
      wallet: w,
      label: tx.label,
      spentTxId: txid,
      kind: AddressKind.external,
      state: AddressStatus.used,
    );

    // final txs = walletBloc.state.wallet!.transactions.toList();
    // final idx = txs.indexWhere((element) => element.txid == tx.txid);
    // if (idx != -1) {
    //   txs.removeAt(idx);
    //   txs.insert(idx, state.tx.copyWith(oldTx: true));
    // } else
    //   txs.add(state.tx.copyWith(oldTx: true));

    // updatedWallet = updatedWallet.copyWith(transactions: txs);

    walletBloc.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [
          UpdateWalletTypes.transactions,
          UpdateWalletTypes.addresses,
        ],
      ),
    );

    walletBloc.add(SyncWallet());

    emit(
      state.copyWith(
        sendingTx: false,
        sentTx: true,
      ),
    );
  }

  void cancelTx() {
    emit(state.copyWith(updatedTx: null));
  }
}
