import 'package:bb_mobile/core/errors/bull_exception.dart';

class BroadcastSignedTxError extends BullException {
  BroadcastSignedTxError(super.message);
}

class InvalidTxError extends BroadcastSignedTxError {
  InvalidTxError()
    : super('Input is not a transaction using PSBT or HEX format');
}

class PushTxNoNdefRecordsError extends BroadcastSignedTxError {
  PushTxNoNdefRecordsError() : super('PushTx: No NDEF records found');
}

class PushTxNoUriError extends BroadcastSignedTxError {
  PushTxNoUriError() : super('PushTx: URI not found');
}

class PushTxMissingFragmentParamsError extends BroadcastSignedTxError {
  PushTxMissingFragmentParamsError()
    : super('PushTx: URI missing fragment params');
}

class UnexpectedError extends BroadcastSignedTxError {
  UnexpectedError(Object e) : super(e.toString());
}
