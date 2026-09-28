import 'package:bb_mobile/core/seed/domain/entity/seed_store_type.dart';

abstract interface class SeedStoreTypeRepository {
  /// Null when the flag has never been written by the storage bootstrap.
  Future<SeedStoreType?> fetch();
}
