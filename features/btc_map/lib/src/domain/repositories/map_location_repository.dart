import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../bull_map_failure.dart';
import '../entities/geo_point.dart';

abstract interface class MapLocationRepository {
  @useResult
  Future<Result<GeoPoint, BullMapFailure>> locate();
}
