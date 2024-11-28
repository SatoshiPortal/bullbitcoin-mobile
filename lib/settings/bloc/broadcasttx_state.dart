import 'package:bb_mobile/_model/transaction.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'broadcasttx_state.freezed.dart';

enum BroadcastTxStep { import, broadcast }

@freezed
class BroadcastTxState with _$BroadcastTxState {
  const factory BroadcastTxState({
    @Default(BroadcastTxStep.import) BroadcastTxStep step,
    @Default('') String tx,
    Transaction? transaction,
    @Default(false) recognizedTx,
    @Default(false) verified,
    int? amount,
    @Default(false) bool loadingFile,
    @Default('') String errLoadingFile,
    @Default(false) bool sent,
    @Default(false) bool extractingTx,
    @Default('') String errExtractingTx,
    String? psbt,
    @Default('') String errPSBT,
    @Default(false) bool broadcastingTx,
    @Default('') String errBroadcastingTx,
    bdk.PartiallySignedTransaction? psbtBDK,
    @Default(false) bool downloadingFile,
    @Default('') String errDownloadingFile,
    @Default(false) bool downloaded,
    @Default(false) bool isSigned,
  }) = _BroadcastTxState;
  const BroadcastTxState._();

  String getErrors() {
    String error = '';
    if (errLoadingFile.isNotEmpty) error += '$errLoadingFile\n';
    if (errExtractingTx.isNotEmpty) error += '$errExtractingTx\n';
    if (errPSBT.isNotEmpty) error += errPSBT;
    if (errBroadcastingTx.isNotEmpty) error += '$errBroadcastingTx\n';
    if (errDownloadingFile.isNotEmpty) error += errDownloadingFile;
    return error;
  }

  bool hasErr() {
    return errLoadingFile.isNotEmpty ||
        errExtractingTx.isNotEmpty ||
        errPSBT.isNotEmpty ||
        errBroadcastingTx.isNotEmpty ||
        errDownloadingFile.isNotEmpty;
  }
}
