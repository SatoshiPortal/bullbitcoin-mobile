sealed class NewCustomServerError extends Error {
  NewCustomServerError();
}

class SaveFailedError extends NewCustomServerError {
  final String? reason;

  SaveFailedError([this.reason]);
}
