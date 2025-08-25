import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/features/metadata/wallet_backup_model.dart';

class ExportMetadataUsecase {
  final LabelRepository _labelRepository;

  ExportMetadataUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<void> execute() async {
    final _ = await _labelRepository.fetchAll();

    final _ = WalletBackupModel(
      version: 1,
      name: 'Bull Wallet',
      description: DateTime.now().millisecondsSinceEpoch.toString(),
      accounts: [],
      network: Network.bitcoin,
    );
  }
}
