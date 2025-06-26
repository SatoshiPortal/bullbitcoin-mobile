import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:satoshifier/satoshifier.dart';

part 'watch_only_wallet_entity.freezed.dart';

@freezed
abstract class WatchOnlyWalletEntity with _$WatchOnlyWalletEntity {
  const factory WatchOnlyWalletEntity({
    required WatchOnly watchOnly,
    @Default('') String label,
    @Default('') String masterFingerprint,
  }) = _WatchOnlyWalletEntity;

  const WatchOnlyWalletEntity._();
}
