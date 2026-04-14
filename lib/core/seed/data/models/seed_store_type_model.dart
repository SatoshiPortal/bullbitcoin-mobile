import 'package:bb_mobile/core/seed/domain/entity/seed_store_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed_store_type_model.freezed.dart';
part 'seed_store_type_model.g.dart';

@freezed
abstract class SeedStoreTypeModel with _$SeedStoreTypeModel {
  const SeedStoreTypeModel._();

  const factory SeedStoreTypeModel({
    required String storageLibrary,
  }) = _SeedStoreTypeModel;

  factory SeedStoreTypeModel.fromJson(Map<String, dynamic> json) =>
      _$SeedStoreTypeModelFromJson(json);

  factory SeedStoreTypeModel.fromEntity(SeedStoreType entity) =>
      SeedStoreTypeModel(
        storageLibrary: entity.storageLibrary.name,
      );

  SeedStoreType toEntity() => SeedStoreType(
        storageLibrary: SeedStorageLibrary.values.byName(storageLibrary),
      );
}
