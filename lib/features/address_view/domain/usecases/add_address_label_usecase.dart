import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart'
    show LabelsFacade, NewLabel;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

class AddAddressLabelUsecase {
  final LabelsFacade _labelsFacade;

  const AddAddressLabelUsecase({required this._labelsFacade});

  @useResult
  Future<Result<void, AddressViewFailure>> execute({
    required String address,
    required String label,
    required String walletId,
  }) async {
    final result = await _labelsFacade.store(
      NewLabel.addr(address: address, label: label, origin: walletId),
    );
    return switch (result) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(
        AddressViewLabelFailure('${failure.runtimeType}'),
      ),
    };
  }
}
