import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class CreateLabelUsecase {
  final LabelRepository _labelRepository;
  final WalletRepository _wallet;

  CreateLabelUsecase({
    required LabelRepository labelRepository,
    required WalletRepository walletRepository,
  })  : _labelRepository = labelRepository,
        _wallet = walletRepository;

  Future<Label> execute({
    required String walletId,
    required LabelType type,
    required String ref,
    required String label,
    bool? spendable,
  }) async {
    try {
      // Get the wallet to calculate origin
      final wallet = await _wallet.getWallet(walletId);
      final origin = wallet.origin;

      final labelEntity = Label.create(
        type: type,
        ref: ref,
        label: label,
        origin: origin,
        spendable: spendable,
      );
      await _labelRepository.store(labelEntity);
      return labelEntity;
    } catch (e) {
      throw CreateLabelException(e.toString());
    }
  }
}

class CreateLabelException implements Exception {
  final String message;

  CreateLabelException(this.message);
}
