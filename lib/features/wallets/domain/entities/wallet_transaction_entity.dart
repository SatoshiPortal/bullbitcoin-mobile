import 'package:bb_mobile/core/primitives/network/network.dart';
import 'package:bb_mobile/core/primitives/transaction/transaction_direction.dart';
import 'package:bb_mobile/core/primitives/transaction/transaction_status.dart';

class WalletTransactionEntity {
  final String _txId;
  final int _walletId;
  final TransactionDirection _direction;
  final Network _network;
  final int _amountSat;
  final int _feeSat;
  DateTime? _confirmationTime;
  TransactionStatus _status;

  WalletTransactionEntity._({
    required String txId,
    required int walletId,
    required Network network,
    required TransactionDirection direction,
    required int amountSat,
    required int feeSat,
    DateTime? confirmationTime,
    required TransactionStatus status,
  }) : _txId = txId,
       _walletId = walletId,
       _network = network,
       _direction = direction,
       _amountSat = amountSat,
       _feeSat = feeSat,
       _confirmationTime = confirmationTime,
       _status = status;

  factory WalletTransactionEntity.fromSnapshot({
    required String txId,
    required int walletId,
    required Network network,
    required TransactionDirection direction,
    required int amountSat,
    required int feeSat,
    DateTime? confirmationTime,
  }) {
    // The domain decides the status based on confirmation time here
    // Other layers should not set status directly since it is a domain concept
    // that can be different for different types of transactions and is based
    // on business rules. The underlying data source may not even have a status field.
    final status = confirmationTime == null
        ? TransactionStatus.pending
        : TransactionStatus.completed;

    return WalletTransactionEntity._(
      txId: txId,
      walletId: walletId,
      network: network,
      direction: direction,
      amountSat: amountSat,
      feeSat: feeSat,
      confirmationTime: confirmationTime,
      status: status,
    );
  }

  String get txId => _txId;
  int get walletId => _walletId;
  TransactionDirection get direction => _direction;
  Network get network => _network;
  int get amountSat => _amountSat;
  int get feeSat => _feeSat;
  DateTime? get confirmationTime => _confirmationTime;
  TransactionStatus get status => _status;
}
