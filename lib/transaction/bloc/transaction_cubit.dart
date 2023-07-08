import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/transaction/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionCubit extends Cubit<TransactionState> {
  TransactionCubit({
    required Transaction tx,
    required this.walletCubit,
    required this.storage,
    required this.walletUpdate,
    required this.walletRead,
    required this.mempoolAPI,
    required this.settingsCubit,
  }) : super(TransactionState(tx: tx)) {
    if (tx.isReceived())
      loadReceiveLabel();
    else
      loadSentLabel();

    loadTx();
  }

  final WalletCubit walletCubit;
  final MempoolAPI mempoolAPI;
  final IStorage storage;
  final WalletUpdate walletUpdate;
  final WalletRead walletRead;
  final SettingsCubit settingsCubit;

  void loadTx() async {
    emit(state.copyWith(loadingAddresses: true, errLoadingAddresses: ''));

    Future.wait([
      // loadInAddresses(),
      loadOutAddresses(),
    ]);

    emit(state.copyWith(loadingAddresses: false));
  }

  Future loadInAddresses() async {
    final (tx, err) = await walletRead.getInputAddresses(
      tx: state.tx,
      wallet: walletCubit.state.wallet!,
      mempoolAPI: mempoolAPI,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errLoadingAddresses: err.toString(),
        ),
      );
      return;
    }

    emit(state.copyWith(tx: tx!));
  }

  Future loadOutAddresses() async {
    final (tx, err) = await walletRead.getOutputAddresses(
      tx: state.tx,
      wallet: walletCubit.state.wallet!,
      mempoolAPI: mempoolAPI,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errLoadingAddresses: err.toString(),
        ),
      );
      return;
    }
    emit(state.copyWith(tx: tx!));
  }

  void loadReceiveLabel() {
    final tx = state.tx;
    final txid = tx.txid;

    final address = walletCubit.state.wallet!.getAddressFromAddresses(txid);

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
  //   final tx = (walletCubit.state.wallet?.transactions ?? []).firstWhere(
  //     (t) => t.txid == state.tx.txid,
  //     orElse: () => state.tx,
  //   );
  //   emit(state.copyWith(label: tx.label ?? ''));
  // }

  void labelChanged(String label) {
    emit(state.copyWith(label: label));
  }

  void saveLabelClicked() async {
    final label = state.tx.label ?? '';
    if (label == state.label) return;
    emit(state.copyWith(savingLabel: true, errSavingLabel: ''));

    final tx = state.tx.copyWith(label: state.label);
    final updateWallet = walletCubit.state.wallet!.copyWith(
      transactions: [
        for (var t in walletCubit.state.wallet?.transactions ?? <Transaction>[])
          if (t.txid == tx.txid) tx else t,
      ],
    );

    final err = await walletUpdate.updateWallet(
      wallet: updateWallet,
      storage: storage,
      walletRead: walletRead,
    );
    if (err != null) {
      emit(
        state.copyWith(
          savingLabel: false,
          errSavingLabel: err.toString(),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        savingLabel: false,
        tx: tx,
      ),
    );
    walletCubit.updateWallet(updateWallet);
  }

  void updateFeeRate(int feeRate) {
    emit(state.copyWith(feeRate: feeRate));
  }

  void buildTx() async {
    emit(state.copyWith(buildingTx: true, errBuildingTx: ''));
    final (newTx, err) = await walletUpdate.buildBumpFeeTx(
      tx: state.tx,
      feeRate: state.feeRate!.toDouble(),
      wallet: walletCubit.state.bdkWallet!,
    );
    if (err != null) {
      emit(
        state.copyWith(
          buildingTx: false,
          errBuildingTx: err.toString(),
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
        buildingTx: false,
        updatedTx: newTx,
      ),
    );
  }

  void sendTx() async {
    emit(state.copyWith(sendingTx: true, errSendingTx: ''));
    final tx = state.updatedTx!;
    final wallet = walletCubit.state.wallet!;
    final blockchain = settingsCubit.state.blockchain!;
    final (wtxid, err) = await walletUpdate.broadcastTxWithWallet(
      psbt: tx.psbt!,
      address: tx.toAddress!,
      wallet: wallet,
      blockchain: blockchain,
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

    final (_, updatedWallet) = await walletUpdate.updateWalletAddress(
      address: (1, tx.toAddress!),
      wallet: wallet,
      label: tx.label,
      sentTxId: txid,
      isSend: true,
    );

    final err2 = await walletUpdate.updateWallet(
      wallet: updatedWallet,
      storage: storage,
      walletRead: walletRead,
    );
    if (err2 != null) {
      emit(state.copyWith(errSendingTx: err2.toString(), sendingTx: false));
      return;
    }

    walletCubit.updateWallet(updatedWallet);

    walletCubit.sync();

    emit(
      state.copyWith(
        sendingTx: false,
        sentTx: true,
      ),
    );
    walletCubit.updateWallet(w);
  }

  void cancelTx() {
    emit(state.copyWith(updatedTx: null));
  }
}

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 

// 
// 
// 


// final txObj = jsonDecode(state.tx.serializedTx!);

// final inputs = txObj['input'] as List<dynamic>;
// final outputs = txObj['output'] as List<dynamic>;

// final inTxs = inputs.map((e) => e['previous_output'] as String).toList();
// final outScripts = outputs.map((e) => e['script_pubkey'] as String).toList();
