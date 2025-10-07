sealed class ElectrumServerError extends Error {
  final String message;

  ElectrumServerError(this.message);

  @override
  String toString() => message;
}

class InvalidPriorityError extends ElectrumServerError {
  final int value;

  InvalidPriorityError(this.value)
    : super('priority must be non-negative, got: $value');
}
