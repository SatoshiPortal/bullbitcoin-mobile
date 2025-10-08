sealed class ElectrumServersException implements Exception {
  ElectrumServersException();
}

class LoadFailedException extends ElectrumServersException {
  final String? reason;

  LoadFailedException([this.reason]);
}

class SavePriorityFailedException extends ElectrumServersException {
  final String? reason;

  SavePriorityFailedException([this.reason]);
}

class AddFailedException extends ElectrumServersException {
  final String? reason;

  AddFailedException([this.reason]);
}

class DeleteFailedException extends ElectrumServersException {
  final String? reason;

  DeleteFailedException([this.reason]);
}
