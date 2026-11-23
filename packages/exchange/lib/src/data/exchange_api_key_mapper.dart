import 'package:primitives/primitives.dart';

import '../domain/entities/exchange_api_key.dart';
import '../domain/exchange_failure.dart';
import 'api_key_model.dart';

abstract final class ExchangeApiKeyMapper {
  static Result<ExchangeApiKey, ExchangeFailure> toDomain(
    ExchangeApiKeyModel model,
  ) => ExchangeApiKey.create(
    id: model.id,
    key: model.key,
    name: model.name,
    userId: model.userId,
    isActive: model.isActive,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
    lastUsedAt: model.lastUsedAt,
    expiresAt: model.expiresAt,
  );

  static ExchangeApiKeyModel toModel(ExchangeApiKey value) =>
      ExchangeApiKeyModel(
        id: value.id,
        key: value.key,
        name: value.name,
        userId: value.userId,
        isActive: value.isActive,
        createdAt: value.createdAt,
        updatedAt: value.updatedAt,
        lastUsedAt: value.lastUsedAt,
        expiresAt: value.expiresAt,
      );
}
