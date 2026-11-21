import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';

import 'package:primitives/primitives.dart';

class DisposeBitBoxConnectionsUsecase {
  final BitBoxDeviceRepository _repository;
  DisposeBitBoxConnectionsUsecase({required this._repository});
  Future<Result<void, BitBoxFailure>> execute() => _repository.dispose();
}
