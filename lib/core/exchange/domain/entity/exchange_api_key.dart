import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

/// A validated credential in transit between authentication and persistence.
/// It must never be retained in presentation state or a service cache.
final class ExchangeApiKey {
  final String id;
  final String key;
  final String name;
  final String userId;
  final bool isActive;
  final int createdAt;
  final int updatedAt;
  final int? lastUsedAt;
  final int? expiresAt;

  const ExchangeApiKey._({
    required this.id,
    required this.key,
    required this.name,
    required this.userId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
    this.expiresAt,
  });

  @useResult
  static Result<ExchangeApiKey, ExchangeApiKeyFailure> create({
    required String id,
    required String key,
    required String name,
    required String userId,
    required bool isActive,
    required int createdAt,
    required int updatedAt,
    int? lastUsedAt,
    int? expiresAt,
  }) {
    if (!isValidKey(key)) return const Err(ExchangeApiKeyInvalidFailure());
    return Ok(
      ExchangeApiKey._(
        id: id,
        key: key,
        name: name,
        userId: userId,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastUsedAt: lastUsedAt,
        expiresAt: expiresAt,
      ),
    );
  }

  /// Reject blank or unsafe header values before transport errors can quote them.
  static bool isValidKey(String key) =>
      key.trim().isNotEmpty &&
      key.codeUnits.every(
        (unit) => unit == 0x09 || (unit >= 0x20 && unit <= 0x7e),
      );

  @override
  String toString() => 'ExchangeApiKey(redacted)';
}
