sealed class ElectrumServersException implements Exception {
  final String message;

  ElectrumServersException(this.message);

  @override
  String toString() => message;
}

class ElectrumServerAlreadyExistsException extends ElectrumServersException {
  final String url;
  ElectrumServerAlreadyExistsException(this.url)
    : super('This server already exists: $url');
}
