class ArkError implements Exception {
  final String message;
  ArkError(this.message);

  @override
  String toString() => message;
}

class ArkDerivationAlreadyExistsError extends ArkError {
  ArkDerivationAlreadyExistsError()
    : super('Ark bip85 derivation already exists');
}

class ArkDerivationNotFoundError extends ArkError {
  ArkDerivationNotFoundError() : super('Ark bip85 derivation not found');
}

class ArkWalletIsNotInitializedError extends ArkError {
  ArkWalletIsNotInitializedError() : super('Ark wallet is not initialized');
}
