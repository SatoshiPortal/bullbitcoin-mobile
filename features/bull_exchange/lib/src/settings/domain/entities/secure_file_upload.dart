import 'package:exchange/exchange.dart';

final class SecureFileUpload {
  final String? userId;
  final KycDocumentStatus? status;

  const SecureFileUpload({required this.userId, required this.status});
}
