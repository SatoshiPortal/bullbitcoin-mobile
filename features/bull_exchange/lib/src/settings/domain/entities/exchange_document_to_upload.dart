/// A picked document that passed the checks, named as the exchange expects.
final class ExchangeDocumentToUpload {
  final List<int> bytes;
  final String fileName;

  const ExchangeDocumentToUpload({required this.bytes, required this.fileName});
}
