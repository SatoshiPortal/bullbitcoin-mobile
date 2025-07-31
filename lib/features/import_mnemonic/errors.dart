class ImportMnemonicError implements Exception {
  final String message;

  ImportMnemonicError(this.message);

  @override
  String toString() => message;
}

class MnemonicIsNullError extends ImportMnemonicError {
  MnemonicIsNullError() : super('No Mnemonic');
}

class EmptyMnemonicLabelError extends ImportMnemonicError {
  EmptyMnemonicLabelError() : super('A label is required to import a mnemonic');
}
