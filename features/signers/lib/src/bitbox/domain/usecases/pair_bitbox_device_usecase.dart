import 'package:signers/src/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:signers/src/bitbox/domain/errors/bitbox_failure.dart';
import 'package:signers/src/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class PairBitBoxDeviceUsecase {
  final BitBoxDeviceRepository _repository;

  PairBitBoxDeviceUsecase({required this._repository});

  @useResult
  Future<Result<String, BitBoxFailure>> execute(BitBoxDeviceEntity device) =>
      _repository.pairDevice(device);
}
