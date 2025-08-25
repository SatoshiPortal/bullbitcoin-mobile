class MetadataError implements Exception {
  final String message;

  MetadataError(this.message);

  @override
  String toString() => message;
}
