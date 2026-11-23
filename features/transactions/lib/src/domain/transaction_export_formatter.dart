import 'package:transactions/src/domain/entities/transaction.dart';

abstract interface class TransactionExportFormatter {
  String format(List<Transaction> transactions);
}
