import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed_store_type.freezed.dart';

enum SeedStorageLibrary {
  fss10,
  fss9,
  // oubliette,
}

@freezed
abstract class SeedStoreType with _$SeedStoreType {
  const SeedStoreType._();

  const factory SeedStoreType({
    required SeedStorageLibrary storageLibrary,
  }) = _SeedStoreType;

  /// Currently fss9. Will include fss10 once oubliette is available.
  bool get isLegacyStorage => storageLibrary == SeedStorageLibrary.fss9;
}
