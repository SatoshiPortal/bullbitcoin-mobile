import 'package:bb_mobile/core_deprecated/labels/data/label_repository.dart';
import 'package:bb_mobile/core_deprecated/labels/domain/label.dart';
import 'package:bb_mobile/core_deprecated/labels/domain/label_error.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_transaction.dart';

class LabelWalletTransactionUsecase {
  final LabelRepository _labelRepository;

  LabelWalletTransactionUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<void> execute({
    required WalletTransaction tx,
    required String label,
  }) async {
    try {
      final transactionLabel = Label.tx(
        transactionId: tx.txId,
        label: label,
        origin: tx.walletId,
      );
      await _labelRepository.store(transactionLabel);
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected(
        'Failed to create label for transaction ${tx.txId}: $e',
      );
    }
  }
}
