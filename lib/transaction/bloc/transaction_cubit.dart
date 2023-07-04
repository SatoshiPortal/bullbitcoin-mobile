import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/interface.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
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

  void checkRBFStatus() {}

  void updateFeeRate(int feeRate) {
    emit(state.copyWith(feeRate: feeRate));
  }

  void buildTx() {}

  void sendTx() {}

  void cancelTx() {}
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
