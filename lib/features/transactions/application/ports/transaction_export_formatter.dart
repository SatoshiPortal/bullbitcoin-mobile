import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';

abstract interface class TransactionExportFormatter {
  String format(List<Transaction> transactions);
}
