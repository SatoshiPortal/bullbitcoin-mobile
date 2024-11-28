import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/utxo.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/transaction/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionCubit extends Cubit<TransactionState> {
  TransactionCubit({
    required Transaction tx,
    required WalletBloc walletBloc,
    required WalletTx walletTx,
    required BDKTransactions bdkTx,
    // required HomeCubit homeCubit,
    required WalletSensitiveStorageRepository walletSensRepository,
    required WalletAddress walletAddress,
    required WalletUpdate walletUpdate,
    required WalletsRepository walletsRepository,
    required BDKSensitiveCreate bdkSensitiveCreate,
  })  : _bdkTx = bdkTx,
        _bdkSensitiveCreate = bdkSensitiveCreate,
        _walletAddress = walletAddress,
        _walletSensRepository = walletSensRepository,
        _walletsRepository = walletsRepository,
        _walletUpdate = walletUpdate,
        _walletTx = walletTx,
        _walletBloc = walletBloc,
        // _homeCubit = homeCubit,
        super(TransactionState(tx: tx)) {
    if (tx.isReceived())
      loadReceiveLabel();
    else
      loadSentLabel();

    loadTx();
  }

  final WalletTx _walletTx;
  final WalletUpdate _walletUpdate;
  final WalletsRepository _walletsRepository;
  final WalletSensitiveStorageRepository _walletSensRepository;
  final WalletAddress _walletAddress;
  final BDKSensitiveCreate _bdkSensitiveCreate;
  final BDKTransactions _bdkTx;

  final WalletBloc _walletBloc;
  // final HomeCubit _homeCubit;

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

    final address = _walletBloc.state.wallet!.getAddressFromAddresses(txid);

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

    final updateWallet = _walletBloc.state.wallet!.copyWith(
      transactions: [
        for (final t
            in _walletBloc.state.wallet?.transactions ?? <Transaction>[])
          if (t.txid == tx.txid) tx else t,
      ],
    );

    final (w, err) = await _walletUpdate.updateAddressesFromTxs(updateWallet);
    if (err != null) {
      emit(state.copyWith(errSavingLabel: err.toString(), savingLabel: false));
      return;
    }
    if (!w!.isLiquid()) {
      try {
        final myAddress = tx.outAddrs
            .where((element) => element.kind != AddressKind.external)
            .first;

        final updatedWallet = await BDKUtxo().updateUtxoLabel(
          addressStr: myAddress.address,
          wallet: w,
          label: state.label,
        );
        if (updatedWallet != null) {
          _walletBloc.add(
            UpdateWallet(
              updatedWallet,
              updateTypes: [
                UpdateWalletTypes.transactions,
                UpdateWalletTypes.addresses,
                UpdateWalletTypes.utxos,
              ],
            ),
          );
        } else {
          _walletBloc.add(
            UpdateWallet(
              w,
              updateTypes: [
                UpdateWalletTypes.transactions,
                UpdateWalletTypes.addresses,
              ],
            ),
          );
        }
      } catch (_) {}
    } else
      _walletBloc.add(
        UpdateWallet(
          w,
          updateTypes: [
            UpdateWalletTypes.transactions,
            UpdateWalletTypes.addresses,
          ],
        ),
      );

    await Future.delayed(const Duration(seconds: 1));
    _walletBloc.add(ListTransactions());

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
  void buildRbfTx(int fee) async {
    emit(state.copyWith(buildingTx: true, errBuildingTx: ''));

    // final isManualFees = _networkFeesCubit.state.feeOption() == 4;
    // int fees = 0;
    // if (!isManualFees)
    //   fees = _networkFeesCubit.state.feesList?[_networkFeesCubit.state.feeOption()] ?? 0;
    // else
    //   fees = _networkFeesCubit.state.fee();
    final fees = fee;

    if (fees == 0) {
      emit(
        state.copyWith(
          buildingTx: false,
          errBuildingTx: 'Fee rate must be greater than 0',
        ),
      );
      return;
    } else if (fees.toDouble() <= (state.tx.feeRate ?? 1.0)) {
      emit(
        state.copyWith(
          buildingTx: false,
          errBuildingTx:
              'New fee rate ($fees sats/vB) must be greater than previous fee rate',
        ),
      );
      return;
    }

    // final walletBloc = _homeCubit.state.getWalletBlocById(state.tx.walletId!);
    final wallet = _walletBloc.state.wallet!;
    // final (wallet, err) = await _walletsStorageRepository.readWallet(
    //   walletHashId: _walletBloc.state.wallet!.getWalletStorageString(),
    // );
    // if (err != null) {
    //   emit(state.copyWith(errBuildingTx: err.toString(), buildingTx: false));
    //   return;
    // }

    final (seed, errRead) = await _walletSensRepository.readSeed(
      fingerprintIndex: wallet.getRelatedSeedStorageString(),
    );

    if (errRead != null) {
      emit(
        state.copyWith(
          errBuildingTx: errRead.toString(),
          buildingTx: false,
        ),
      );
      return;
    }

    final (bdkSignerWallet, errLoad) =
        await _bdkSensitiveCreate.loadPrivateBdkWallet(wallet, seed!);
    if (errLoad != null) {
      emit(
        state.copyWith(
          errBuildingTx: errLoad.toString(),
          buildingTx: false,
        ),
      );
      return;
    }

    final (pubBdkWallet, errGet) = _walletsRepository.getBdkWallet(wallet.id);
    if (errGet != null) {
      emit(
        state.copyWith(
          errBuildingTx: errGet.toString(),
          buildingTx: false,
        ),
      );
      return;
    }

    final (newTx, errBuild) = await _bdkTx.buildBumpFeeTx(
      tx: state.tx,
      feeRate: fees.toDouble(),
      signingWallet: bdkSignerWallet!,
      pubWallet: pubBdkWallet!,
    );
    if (errBuild != null) {
      emit(
        state.copyWith(
          buildingTx: false,
          errBuildingTx: errBuild.toString(),
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
    final tx = state.tx.swapTx != null
        ? state.updatedTx!.copyWith(swapTx: state.tx.swapTx, isSwap: true)
        : state.updatedTx!;
    final wallet = _walletBloc.state.wallet!;

    final (wtxid, err) = await _walletTx.broadcastTxWithWallet(
      address: tx.toAddress!,
      wallet: wallet,
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

    final (_, updatedWallet) = await _walletAddress.addAddressToWallet(
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

    final (updatedWallet2, err2) =
        await _walletUpdate.removePrevTxofRbf(updatedWallet, state.tx, tx);
    if (err2 != null) {
      emit(
        state.copyWith(
          sendingTx: false,
          errSendingTx: err2.toString(),
        ),
      );
      return;
    }

    _walletBloc.add(
      UpdateWallet(
        updatedWallet2!,
        updateTypes: [
          UpdateWalletTypes.transactions,
          UpdateWalletTypes.addresses,
        ],
      ),
    );

    _walletBloc.add(SyncWallet());

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
