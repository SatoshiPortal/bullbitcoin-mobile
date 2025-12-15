sealed class SetAdvancedElectrumOptionsExceptions implements Exception {
  final String message;

  SetAdvancedElectrumOptionsExceptions(this.message);

  @override
  String toString() => message;
}

class SaveFailedException extends SetAdvancedElectrumOptionsExceptions {
  final String? reason;

  SaveFailedException([this.reason])
    : super('Failed to save advanced Electrum options. Reason: $reason');
}
