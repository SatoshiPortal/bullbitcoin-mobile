import 'package:freezed_annotation/freezed_annotation.dart';

part 'pool_configuration_update_model.freezed.dart';
part 'pool_configuration_update_model.g.dart';

/// Model for PATCH /api/system payload
@freezed
sealed class PoolConfigurationUpdateModel with _$PoolConfigurationUpdateModel {
  const factory PoolConfigurationUpdateModel({
    required String stratumURL,
    required int stratumPort,
    required String stratumUser,
    required bool stratumExtranonceSubscribe,
    required int stratumSuggestedDifficulty,
    required String fallbackStratumURL,
    required int fallbackStratumPort,
    required String fallbackStratumUser,
    required bool fallbackStratumExtranonceSubscribe,
    required int fallbackStratumSuggestedDifficulty,
  }) = _PoolConfigurationUpdateModel;

  factory PoolConfigurationUpdateModel.fromJson(Map<String, dynamic> json) =>
      _$PoolConfigurationUpdateModelFromJson(json);

  /// Convert to JSON for API request
  @override
  Map<String, dynamic> toJson() => {
    'stratumURL': stratumURL,
    'stratumPort': stratumPort,
    'stratumUser': stratumUser,
    'stratumExtranonceSubscribe': stratumExtranonceSubscribe,
    'stratumSuggestedDifficulty': stratumSuggestedDifficulty,
    'fallbackStratumURL': fallbackStratumURL,
    'fallbackStratumPort': fallbackStratumPort,
    'fallbackStratumUser': fallbackStratumUser,
    'fallbackStratumExtranonceSubscribe': fallbackStratumExtranonceSubscribe,
    'fallbackStratumSuggestedDifficulty': fallbackStratumSuggestedDifficulty,
  };
}
