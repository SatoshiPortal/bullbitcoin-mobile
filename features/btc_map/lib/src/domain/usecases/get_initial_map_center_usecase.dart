import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../bull_map_failure.dart';
import '../entities/geo_point.dart';
import '../repositories/map_location_repository.dart';

class GetInitialMapCenterUsecase {
  final MapLocationRepository _repository;

  const GetInitialMapCenterUsecase(this._repository);

  @useResult
  Future<Result<GeoPoint, BullMapFailure>> execute() => _repository.locate();
}
