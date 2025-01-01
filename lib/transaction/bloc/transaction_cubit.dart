import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/utxo.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_repository/apps_wallets_repository.dart';
import 'package:bb_mobile/_repository/wallet/internal_wallets.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';
import 'package:bb_mobile/transaction/bloc/state.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionCubit extends Cubit<TransactionState> {
  TransactionCubit({
    required Transaction tx,
    required Wallet wallet,
    required WalletTx walletTx,
    required BDKTransactions bdkTx,
    required WalletSensitiveStorageRepository walletSensRepository,
    required WalletAddress walletAddress,
    required WalletUpdate walletUpdate,
    required InternalWalletsRepository walletsRepository,
    required BDKSensitiveCreate bdkSensitiveCreate,
    required AppWalletsRepository appWalletsRepository,
  })  : _bdkTx = bdkTx,
        _bdkSensitiveCreate = bdkSensitiveCreate,
        _walletAddress = walletAddress,
        _walletSensRepository = walletSensRepository,
        _walletsRepository = walletsRepository,
        _walletUpdate = walletUpdate,
        _appWalletsRepository = appWalletsRepository,
        _walletTx = walletTx,
        _wallet = wallet,
        super(TransactionState(tx: tx)) {
    if (tx.isReceived()) {
      loadReceiveLabel();
    } else {
      loadSentLabel();
    }

    loadTx();
  }

  final WalletTx _walletTx;
  final WalletUpdate _walletUpdate;
  final InternalWalletsRepository _walletsRepository;
  final WalletSensitiveStorageRepository _walletSensRepository;
  final WalletAddress _walletAddress;
  final BDKSensitiveCreate _bdkSensitiveCreate;
  final BDKTransactions _bdkTx;
  final AppWalletsRepository _appWalletsRepository;

  final Wallet _wallet;

  Future<void> loadTx() async {
    emit(state.copyWith(loadingAddresses: true, errLoadingAddresses: ''));

    Future.wait([]);

    emit(state.copyWith(loadingAddresses: false));
  }

  void loadReceiveLabel() {
    final tx = state.tx;
    final txid = tx.txid;

    final address = _wallet.getAddressFromAddresses(txid);

    if (address == null || address.label == null) return;

    emit(
      state.copyWith(
        tx: tx.copyWith(label: address.label),
        label: address.label!,
      ),
    );
  }

  void loadSentLabel() {}

  void labelChanged(String label) {
    emit(state.copyWith(label: label));
  }

  Future<void> saveLabelClicked() async {
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

    final updateWallet = _wallet.copyWith(
      transactions: [
        for (final t in _wallet.transactions)
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
          await _appWalletsRepository
              .getWalletServiceById(updatedWallet.id)
              ?.updateWallet(
            updatedWallet,
            updateTypes: [
              UpdateWalletTypes.transactions,
              UpdateWalletTypes.addresses,
              UpdateWalletTypes.utxos,
            ],
          );
        } else {
          await _appWalletsRepository.getWalletServiceById(w.id)?.updateWallet(
            w,
            updateTypes: [
              UpdateWalletTypes.transactions,
              UpdateWalletTypes.addresses,
            ],
          );
        }
      } catch (_) {}
    } else {
      await _appWalletsRepository.getWalletServiceById(w.id)?.updateWallet(
        w,
        updateTypes: [
          UpdateWalletTypes.transactions,
          UpdateWalletTypes.addresses,
        ],
      );
    }

    await _appWalletsRepository.getWalletServiceById(w.id)?.listTransactions();

    emit(
      state.copyWith(
        savingLabel: false,
        tx: tx,
      ),
    );
  }

  Future<void> buildRbfTx(int fee) async {
    emit(state.copyWith(buildingTx: true, errBuildingTx: ''));

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

    final (seed, errRead) = await _walletSensRepository.readSeed(
      fingerprintIndex: _wallet.getRelatedSeedStorageString(),
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
        await _bdkSensitiveCreate.loadPrivateBdkWallet(_wallet, seed!);
    if (errLoad != null) {
      emit(
        state.copyWith(
          errBuildingTx: errLoad.toString(),
          buildingTx: false,
        ),
      );
      return;
    }

    final (pubBdkWallet, errGet) = _walletsRepository.getBdkWallet(_wallet.id);
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
        updatedTx: newTx,
      ),
    );

    await Future.delayed(200.ms);
    sendTx();
  }

  Future<void> sendTx() async {
    emit(state.copyWith(sendingTx: true, errSendingTx: '', buildingTx: false));
    final tx = state.tx.swapTx != null
        ? state.updatedTx!.copyWith(swapTx: state.tx.swapTx, isSwap: true)
        : state.updatedTx!;
    final wallet = _wallet;

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

    await _appWalletsRepository
        .getWalletServiceById(updatedWallet2!.id)
        ?.updateWallet(
      updatedWallet2,
      updateTypes: [
        UpdateWalletTypes.transactions,
        UpdateWalletTypes.addresses,
      ],
    );

    await _appWalletsRepository
        .getWalletServiceById(updatedWallet2.id)
        ?.syncWallet();

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
