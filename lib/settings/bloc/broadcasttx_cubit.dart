import 'dart:io';

import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/settings/bloc/broadcasttx_state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
// import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
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
    final tx = file!;
    emit(state.copyWith(loadingFile: false, tx: tx));
  }

  void extractTxClicked() async {
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
    // } catch (e) {
    //   emit(state.copyWith(extractingTx: false, errExtractingTx: e.toString()));
    // }
  }

  void downloadPSBTClicked() async {
    emit(state.copyWith(downloadingFile: true, errDownloadingFile: ''));
    final psbt = state.psbtBDK?.psbtBase64;
    if (psbt == null || psbt.isEmpty) {
      emit(state.copyWith(downloadingFile: false, errDownloadingFile: 'No PSBT'));
      return;
    }

    final txid = state.transaction?.txid;
    if (txid == null || txid.isEmpty) {
      emit(state.copyWith(downloadingFile: false, errDownloadingFile: 'No TXID'));
      return;
    }

    final (appDocDir, err) = await fileStorage.getDownloadDirectory();
    if (err != null) throw err;
    final file = File(appDocDir! + '/bullbitcoin_psbt/$txid.psbt');
    final (_, errSave) = await fileStorage.saveToFile(file, psbt);
    if (errSave != null) {
      emit(state.copyWith(downloadingFile: false, errDownloadingFile: errSave.toString()));
      return;
    }

    emit(state.copyWith(downloadingFile: false, downloaded: true));
    await Future.delayed(const Duration(seconds: 4));
    emit(state.copyWith(downloaded: false));
  }

  void broadcastClicked() async {
    emit(state.copyWith(broadcastingTx: true, errBroadcastingTx: ''));
    final psbt = state.psbtBDK;
    if (psbt == null) {
      emit(state.copyWith(broadcastingTx: false, errBroadcastingTx: 'No PSBT'));
      return;
    }

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
      psbt: psbt,
      blockchain: blockchain,
    );
    if (err != null) {
      emit(state.copyWith(broadcastingTx: false, errBroadcastingTx: err.toString()));
      return;
    }
    emit(state.copyWith(broadcastingTx: false, sent: true));
  }
}
