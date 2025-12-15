import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';

class ImportMnemonicError extends BullException {
  ImportMnemonicError(super.message);
}

class MnemonicIsNullError extends ImportMnemonicError {
  MnemonicIsNullError() : super('No Mnemonic');
}

class EmptyMnemonicLabelError extends ImportMnemonicError {
  EmptyMnemonicLabelError() : super('A label is required to import a mnemonic');
}
