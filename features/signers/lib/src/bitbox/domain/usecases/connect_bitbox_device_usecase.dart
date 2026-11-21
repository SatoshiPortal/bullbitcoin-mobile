import 'package:signers/src/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:signers/src/bitbox/domain/errors/bitbox_failure.dart';
import 'package:signers/src/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class ConnectBitBoxDeviceUsecase {
  final BitBoxDeviceRepository _repository;

  ConnectBitBoxDeviceUsecase({required this._repository});

  @useResult
  Future<Result<void, BitBoxFailure>> execute(BitBoxDeviceEntity device) =>
      _repository.connectDevice(device);
}
