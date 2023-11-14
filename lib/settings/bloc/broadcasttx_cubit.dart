import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/broadcasttx_state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BroadcastTxCubit extends Cubit<BroadcastTxState> {
  BroadcastTxCubit({
    required this.barcode,
    required this.filePicker,
    required this.fileStorage,
    required this.walletTx,
    required this.homeCubit,
    required this.networkCubit,
  }) : super(const BroadcastTxState());

  final FilePick filePicker;
  final Barcode barcode;
  final FileStorage fileStorage;
  final WalletTx walletTx;
  final HomeCubit homeCubit;
  final NetworkCubit networkCubit;

  void txChanged(String tx) {
    emit(state.copyWith(tx: tx));
  }

  void scanQRClicked() async {
    emit(state.copyWith(loadingFile: true, errLoadingFile: ''));
    final (file, err) = await barcode.scan();
    if (err != null) {
      emit(state.copyWith(loadingFile: false, errLoadingFile: err.toString()));
      return;
    }

    final tx = file!;
    emit(state.copyWith(loadingFile: false, tx: tx));
  }

  void uploadFileClicked() async {
    emit(state.copyWith(loadingFile: true, errLoadingFile: ''));
    final (file, err) = await filePicker.pickFile();
    if (err != null) {
      emit(state.copyWith(loadingFile: false, errLoadingFile: err.toString()));
      return;
    }
    // remove carriage return and newline from file read strings
    final tx = file!.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
    emit(state.copyWith(loadingFile: false, tx: tx));
  }

  void extractTxClicked() async {
    try {
      emit(
        state.copyWith(
          extractingTx: true,
          errExtractingTx: '',
          verified: false,
        ),
      );
      final tx = state.tx;
      var isPsbt = false;
      try {
        // check if = is in the string
        hex.decode(tx);
      } catch (e) {
        isPsbt = true;
      }

      if (isPsbt) {
        final psbt = bdk.PartiallySignedTransaction(psbtBase64: tx);
        bdk.Transaction bdkTx = await psbt.extractTx();
        final txid = await bdkTx.txid();

        // loop wallet txs if txid match
        // get address
        // check if psbt outaddresses matches send tx address
        // if not show warning
        // if no tx matches skip checks
        Transaction? transaction;
        WalletBloc? relatedWallet;
        final wallets = homeCubit.state.walletBlocs ?? [];

        for (final wallet in wallets) {
          for (final tx in wallet.state.wallet?.unsignedTxs ?? <Transaction>[]) {
            if (tx.txid == txid && !tx.isReceived()) {
              transaction = tx;
              relatedWallet = wallet;
            }
          }
        }
        if (transaction != null) {
          emit(
            state.copyWith(
              recognizedTx: true,
            ),
          );
          if (relatedWallet == null) {
            emit(
              state.copyWith(
                errExtractingTx: 'Could not load related wallet',
              ),
            );
            return;
          }
          final (bdkTxFin, txErr) = await walletTx.finalizeTx(
            psbt: tx,
            bdkWallet: relatedWallet.state.bdkWallet!,
          );
          if (txErr != null) {
            emit(
              state.copyWith(
                errExtractingTx: 'Error finalizing psbt. Ensure the psbt is signed.',
              ),
            );
            return;
          } else
            bdkTx = bdkTxFin!;
        } else {
          emit(
            state.copyWith(
              recognizedTx: false,
            ),
          );
        }
        final feeAmount = await psbt.feeAmount();
        final outputs = await bdkTx.output();

        int totalAmount = 0;
        final List<Address> outAddrs = [];

        final nOutputs = outputs.length;
        int verifiedOutputs = 0;
        for (final outpoint in outputs) {
          totalAmount += outpoint.value;
          final addressStruct = await bdk.Address.fromScript(
            outpoint.scriptPubkey,
            networkCubit.state.getBdkNetwork(),
          );
          if (transaction != null) {
            try {
              final Address relatedAddress = transaction.outAddrs.firstWhere(
                (element) =>
                    element.address == addressStruct.toString() &&
                    element.highestPreviousBalance == outpoint.value,
              );
              outAddrs.add(
                relatedAddress,
              );
              verifiedOutputs += 1;
            } catch (e) {
              outAddrs.add(
                Address(
                  address: addressStruct.toString(),
                  kind: AddressKind.external,
                  state: AddressStatus.used,
                  highestPreviousBalance: outpoint.value,
                ),
              );
            }
          } else {
            outAddrs.add(
              Address(
                address: addressStruct.toString(),
                kind: AddressKind.external,
                state: AddressStatus.used,
                highestPreviousBalance: outpoint.value,
              ),
            );
          }
        }

        transaction ??= Transaction(txid: txid, timestamp: DateTime.now().microsecondsSinceEpoch);
        transaction = transaction.copyWith(
          fee: feeAmount,
          outAddrs: outAddrs,
        );
        final decodedTx = hex.encode(await bdkTx.serialize());
        if (verifiedOutputs == nOutputs) {
          emit(state.copyWith(verified: true));
        }
        emit(
          state.copyWith(
            extractingTx: false,
            tx: decodedTx,
            psbtBDK: psbt,
            transaction: transaction,
            step: BroadcastTxStep.broadcast,
            amount: totalAmount,
            // this is the sum of outputs so its not really what we are sending
          ),
        );
      } else {
        // its a hex

        final bdkTx = await bdk.Transaction.create(transactionBytes: hex.decode(tx));
        final txid = await bdkTx.txid();
        final outputs = await bdkTx.output();
        Transaction? transaction;
        final wallets = homeCubit.state.walletBlocs ?? [];
        for (final wallet in wallets) {
          for (final tx in wallet.state.wallet?.transactions ?? <Transaction>[]) {
            if (tx.txid == txid) {
              transaction = tx;
            }
          }
        }
        int totalAmount = 0;
        final nOutputs = outputs.length;
        int verifiedOutputs = 0;

        final List<Address> outAddrs = [];
        for (final outpoint in outputs) {
          totalAmount += outpoint.value;
          final addressStruct = await bdk.Address.fromScript(
            outpoint.scriptPubkey,
            networkCubit.state.getBdkNetwork(),
          );
          if (transaction != null) {
            try {
              final Address relatedAddress = transaction.outAddrs.firstWhere(
                (element) =>
                    element.address == addressStruct.toString() &&
                    element.highestPreviousBalance == outpoint.value,
              );
              outAddrs.add(
                relatedAddress,
              );
              verifiedOutputs += 1;
            } catch (e) {
              outAddrs.add(
                Address(
                  address: addressStruct.toString(),
                  kind: AddressKind.external,
                  state: AddressStatus.used,
                  highestPreviousBalance: outpoint.value,
                ),
              );
            }
          } else {
            outAddrs.add(
              Address(
                address: addressStruct.toString(),
                kind: AddressKind.external,
                state: AddressStatus.used,
                highestPreviousBalance: outpoint.value,
              ),
            );
          }
        }
        final int feeAmount = transaction?.fee ?? 0;
        // TODO: timestamp needs to be properly set
        transaction ??= Transaction(
          txid: txid,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        // transaction ??= Transaction(txid: txid);
        transaction = transaction.copyWith(
          fee: feeAmount,
          outAddrs: outAddrs,
        );
        final decodedTx = hex.encode(await bdkTx.serialize());
        if (verifiedOutputs == nOutputs) {
          emit(state.copyWith(verified: true));
        }
        emit(
          state.copyWith(
            extractingTx: false,
            tx: decodedTx,
            transaction: transaction,
            step: BroadcastTxStep.broadcast,
            amount: totalAmount,
            // this is the sum of outputs so its not really what we are sending
          ),
        );
        // final outAddrsFutures = outputs.map((txOut) async {
        //   final scriptAddress = await bdk.Address.fromScript(
        //     txOut.scriptPubkey,
        //     network,
        //   );
        //   if (txOut.value == amount! && scriptAddress.toString() == address) {
        //     return Address(
        //       address: scriptAddress.toString(),
        //       kind: AddressKind.external,
        //       state: AddressStatus.used,
        //       highestPreviousBalance: amount,
        //       label: note ?? '',
        //     );
        //   } else {
        //     return Address(
        //       address: scriptAddress.toString(),
        //       kind: AddressKind.change,
        //       state: AddressStatus.used,
        //       highestPreviousBalance: txOut.value,
        //       label: note ?? '',
        //     );
        //   }
        // });

        // final List<Address> outAddrs = await Future.wait(outAddrsFutures);
      }
    } catch (e) {
      emit(
        state.copyWith(
          extractingTx: false,
          errExtractingTx: e.toString(),
          // step: BroadcastTxStep.import,
          tx: '',
        ),
      );
    }
  }

  void broadcastClicked() async {
    emit(
      state.copyWith(
        broadcastingTx: true,
        errBroadcastingTx: '',
        errExtractingTx: '',
      ),
    );
    final tx = state.tx;
    final bdkTx = await bdk.Transaction.create(transactionBytes: hex.decode(tx));
    final blockchain = networkCubit.state.blockchain;
    if (blockchain == null) {
      emit(
        state.copyWith(
          broadcastingTx: false,
          errBroadcastingTx: 'No Blockchain. Check Electrum Server Settings.',
        ),
      );
      return;
    }

    final err = await walletTx.broadcastTx(
      tx: bdkTx,
      blockchain: blockchain,
    );
    if (err != null) {
      // final error =
      emit(
        state.copyWith(
          broadcastingTx: false,
          errBroadcastingTx:
              'Failed to Broadcast.\n\nCheck the following:\n- Internet connection\n- PSBT must be unspent, signed & finalized\n- Electrum server availability\nColdCard: Use the -final.txn file.',
        ),
      );
      return;
    }
    emit(state.copyWith(broadcastingTx: false, sent: true));
  }

  void downloadPSBTClicked() async {
    emit(state.copyWith(downloadingFile: true, errDownloadingFile: ''));
    final psbt = state.psbtBDK?.psbtBase64;
    if (psbt == null || psbt.isEmpty) {
      emit(
        state.copyWith(
          downloadingFile: false,
          errDownloadingFile: 'No PSBT',
        ),
      );
      return;
    }

    final txid = state.transaction?.txid;
    if (txid == null || txid.isEmpty) {
      emit(
        state.copyWith(
          downloadingFile: false,
          errDownloadingFile: 'No TXID',
        ),
      );
      return;
    }

    // final (appDocDir, err) = await fileStorage.getDownloadDirectory();
    // if (err != null) {
    //   emit(
    //     state.copyWith(
    //       downloadingFile: false,
    //       errDownloadingFile: err.toString(),
    //     ),
    //   );
    //   return;
    // }
    // final file = File(appDocDir! + '/bullbitcoin_psbt/$txid.psbt');
    final errSave = await fileStorage.savePSBT(
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

    emit(state.copyWith(downloadingFile: false, downloaded: true));
    await Future.delayed(const Duration(seconds: 4));
    emit(state.copyWith(downloaded: false));
  }

  void clearErrors() async {
    emit(
      state.copyWith(
        errBroadcastingTx: '',
        errExtractingTx: '',
        errLoadingFile: '',
        errPSBT: '',
        errDownloadingFile: '',
      ),
    );
  }
}
