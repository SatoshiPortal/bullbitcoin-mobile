import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed_store_type.freezed.dart';

enum SeedStorageLibrary {
  fss10,
  fss9,
  oubliette,
}

@freezed
abstract class SeedStoreType with _$SeedStoreType {
  const factory SeedStoreType({
    required SeedStorageLibrary storageLibrary,
  }) = _SeedStoreType;
}
