sealed class ElectrumServersError extends Error {
  ElectrumServersError();
}

class LoadFailedError extends ElectrumServersError {
  final String? reason;

  LoadFailedError([this.reason]);
}

class SavePriorityFailedError extends ElectrumServersError {
  final String? reason;

  SavePriorityFailedError([this.reason]);
}

class DeleteFailedError extends ElectrumServersError {
  final String? reason;

  DeleteFailedError([this.reason]);
}
