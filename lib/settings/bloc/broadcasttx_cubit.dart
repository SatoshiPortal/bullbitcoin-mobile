import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/settings/bloc/broadcasttx_state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BroadcastTxCubit extends Cubit<BroadcastTxState> {
  BroadcastTxCubit({
    required this.barcode,
    required this.filePicker,
    required this.settingsCubit,
    required this.fileStorage,
    required this.walletUpdate,
  }) : super(const BroadcastTxState());

  final FilePick filePicker;
  final SettingsCubit settingsCubit;
  final Barcode barcode;
  final FileStorage fileStorage;
  final WalletUpdate walletUpdate;

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
      emit(state.copyWith(extractingTx: true, errExtractingTx: ''));
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
        final bdkTx = await psbt.extractTx();
        final txid = await bdkTx.txid();
        final feeAmount = await psbt.feeAmount();
        final outputs = await bdkTx.output();
        final List<String> outAddresses = [];
        for (final outpoint in outputs) {
          outAddresses.add(outpoint.toString());
        }

        final transaction = Transaction(
          txid: txid,
          fee: feeAmount,
          outAddresses: outAddresses,
        );

        emit(
          state.copyWith(
            extractingTx: false,
            tx: hex.encode(await bdkTx.serialize()),
            psbtBDK: psbt,
            transaction: transaction,
            step: BroadcastTxStep.broadcast,
          ),
        );
      } else {
        final bdkTx = await bdk.Transaction.create(transactionBytes: hex.decode(tx));
        final txid = await bdkTx.txid();
        final outputs = await bdkTx.output();
        final List<String> outAddresses = [];
        for (final outpoint in outputs) {
          outAddresses.add(outpoint.toString());
        }

        final transaction = Transaction(
          txid: txid,
          // fee: feeAmount,
          outAddresses: outAddresses,
        );

        emit(
          state.copyWith(
            extractingTx: false,
            transaction: transaction,
            step: BroadcastTxStep.broadcast,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          extractingTx: false,
          errExtractingTx: e.toString(),
          // step: BroadcastTxStep.import,
        ),
      );
    }
  }

  void broadcastClicked() async {
    emit(state.copyWith(broadcastingTx: true, errBroadcastingTx: ''));
    final tx = state.tx;
    final bdkTx = await bdk.Transaction.create(transactionBytes: hex.decode(tx));
    final blockchain = settingsCubit.state.blockchain;
    if (blockchain == null) {
      emit(
        state.copyWith(
          broadcastingTx: false,
          errBroadcastingTx: 'No Blockchain',
        ),
      );
      return;
    }

    final err = await walletUpdate.broadcastTx(
      tx: bdkTx,
      blockchain: blockchain,
    );
    if (err != null) {
      emit(
        state.copyWith(
          broadcastingTx: false,
          errBroadcastingTx: err.toString(),
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
}
