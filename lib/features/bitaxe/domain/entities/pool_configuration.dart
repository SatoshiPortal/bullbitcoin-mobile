import 'package:freezed_annotation/freezed_annotation.dart';

part 'pool_configuration.freezed.dart';

/// Domain entity representing pool configuration
@freezed
sealed class PoolConfiguration with _$PoolConfiguration {
  const factory PoolConfiguration({
    required String stratumURL,
    required int stratumPort,
    required String stratumUser,
    required bool stratumExtranonceSubscribe,
    required int stratumSuggestedDifficulty,
  }) = _PoolConfiguration;

  const PoolConfiguration._();

  /// Business logic: Get formatted pool address
  String get formattedAddress => '$stratumURL:$stratumPort';

  /// Business logic: Extract Bitcoin address from username
  /// Format: {bitcoinAddress}.{hostname}
  String? get bitcoinAddress {
    final parts = stratumUser.split('.');
    if (parts.length >= 2) {
      return parts[0]; // Return the Bitcoin address part
    }
    return null;
  }
}
