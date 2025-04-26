import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';

abstract class UtxoRepository {
  Future<List<TransactionOutput>> getUtxos({
    required String walletId,
  });
}
