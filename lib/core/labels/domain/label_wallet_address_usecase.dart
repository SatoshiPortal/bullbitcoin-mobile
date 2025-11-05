import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/labels/domain/label_error.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

class LabelWalletAddressUsecase {
  final LabelRepository _labelRepository;

  LabelWalletAddressUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<void> execute({
    required WalletAddress address,
    required String label,
  }) async {
    try {
      final addressLabel = Label.addr(
        address: address.address,
        label: label,
        origin: address.walletId,
      );
      await _labelRepository.store(addressLabel);
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected(
        'Failed to create label for address ${address.address}: $e',
      );
    }
  }
}
