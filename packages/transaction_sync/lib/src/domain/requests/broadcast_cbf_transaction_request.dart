import 'dart:typed_data';
import '../../wallet_source_session.dart';
import '../wallet_source_registration.dart';

final class BroadcastCbfTransactionRequest {
  final WalletSourceRegistration registration;
  final Uint8List transactionBytes;
  final WalletSourceSession? session;

  BroadcastCbfTransactionRequest({
    required this.registration,
    required Uint8List transactionBytes,
    this.session,
  }) : transactionBytes = Uint8List.fromList(transactionBytes);
}
