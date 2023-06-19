import 'dart:io';

import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file.dart';
import 'package:bb_mobile/settings/bloc/broadcasttx_state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
// import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

class BroadcastTxCubit extends Cubit<BroadcastTxState> {
  BroadcastTxCubit({
    required this.barcode,
    required this.filePicker,
    required this.settingsCubit,
  }) : super(const BroadcastTxState());

  final FilePick filePicker;
  final SettingsCubit settingsCubit;
  final Barcode barcode;

  void txChanged(String tx) {
    emit(state.copyWith(tx: tx));
  }

  void scanQRClicked() async {
    try {
      emit(state.copyWith(loadingFile: true, errLoadingFile: ''));
      final (file, err) = await barcode.scan();
      if (err != null) throw err;

      final tx = file!;
      emit(state.copyWith(loadingFile: false, tx: tx));
    } catch (e) {
      emit(state.copyWith(loadingFile: false, errLoadingFile: e.toString()));
    }
  }

  void uploadFileClicked() async {
    try {
      emit(state.copyWith(loadingFile: true, errLoadingFile: ''));
      final (file, err) = await filePicker.pickFile();
      if (err != null) throw err;
      final tx = file!;
      emit(state.copyWith(loadingFile: false, tx: tx));
    } catch (e) {
      emit(state.copyWith(loadingFile: false, errLoadingFile: e.toString()));
    }
  }

  void extractTxClicked() async {
    try {
      emit(state.copyWith(extractingTx: true, errExtractingTx: ''));
      // final tx = state.tx;
      // final psbt = bdk.PartiallySignedTransaction(psbtBase64: tx);
      // await psbt.extractTx();

      // final details = psbt.txDetails;
      // if (details == null) throw 'No Details';

      // final transaction = Transaction(
      //   txid: details.txid,
      //   sent: details.sent,
      //   received: details.received,
      //   fee: details.fee,
      // );

      // emit(
      //   state.copyWith(
      //     psbtBDK: psbt,
      //     transaction: transaction,
      //     step: BroadcastTxStep.broadcast,
      //   ),
      // );
    } catch (e) {
      emit(state.copyWith(extractingTx: false, errExtractingTx: e.toString()));
    }
  }

  void downloadPSBTClicked() async {
    try {
      emit(state.copyWith(downloadingFile: true, errDownloadingFile: ''));
      final psbt = state.psbtBDK?.psbtBase64;
      if (psbt == null) throw 'No PSBT';
      final txid = state.transaction?.txid;
      if (txid == null) throw 'No TXID';

      final appDocDir = await getDownloadsDirectory();
      if (appDocDir == null) throw 'Could not get downloads directory';
      final file = File(appDocDir.path + '/bullbitcoin_psbt/$txid');
      await file.writeAsString(psbt);

      emit(state.copyWith(downloadingFile: false, downloaded: true));
      await Future.delayed(const Duration(seconds: 4));
      emit(state.copyWith(downloaded: true));
    } catch (e) {
      emit(state.copyWith(
          downloadingFile: false, errDownloadingFile: e.toString()));
    }
  }

  void broadcastClicked() async {
    try {
      emit(state.copyWith(broadcastingTx: true, errBroadcastingTx: ''));
      final psbt = state.psbtBDK;
      final blockchain = settingsCubit.state.blockchain;

      final tx = await psbt!.extractTx();

      await blockchain!.broadcast(tx);
      emit(state.copyWith(broadcastingTx: false, sent: true));
    } catch (e) {
      emit(state.copyWith(
          broadcastingTx: false, errBroadcastingTx: e.toString()));
    }
  }
}
