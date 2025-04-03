import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';

class CreateLabelUsecase {
  final LabelRepository _labelRepository;
  final WalletManagerService _walletManagerService;

  CreateLabelUsecase({
    required LabelRepository labelRepository,
    required WalletManagerService walletManagerService,
  })  : _labelRepository = labelRepository,
        _walletManagerService = walletManagerService;

  Future<Label> execute({
    required String walletId,
    required LabelType type,
    required String ref,
    required String label,
    bool? spendable,
  }) async {
    // Get the wallet to calculate origin
    final wallet = await _walletManagerService.getWallet(walletId);
    final origin = wallet?.getOrigin();

    final labelEntity = Label.create(
      type: type,
      ref: ref,
      label: label,
      origin: origin,
      spendable: spendable,
    );
    await _labelRepository.createLabel(labelEntity);
    return labelEntity;
  }
}
