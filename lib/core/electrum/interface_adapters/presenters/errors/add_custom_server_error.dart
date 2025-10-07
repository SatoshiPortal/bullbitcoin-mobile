sealed class AddCustomServerError extends Error {
  AddCustomServerError();
}

class SaveFailedError extends AddCustomServerError {
  final String? reason;

  SaveFailedError([this.reason]);
}
