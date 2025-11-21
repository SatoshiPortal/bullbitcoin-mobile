import 'package:bb_mobile/core/swaps/domain/entity/boltz_network.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'boltz_network_model.freezed.dart';

@freezed
sealed class BoltzNetworkModel with _$BoltzNetworkModel {
  const factory BoltzNetworkModel({required String value}) = _BoltzNetworkModel;

  const BoltzNetworkModel._();

  factory BoltzNetworkModel.fromEntity(BoltzNetwork entity) {
    return BoltzNetworkModel(value: entity.value);
  }

  BoltzNetwork toEntity() {
    return switch (value) {
      'testnet' => BoltzNetwork.testnet,
      'mainnet' => BoltzNetwork.mainnet,
      _ => throw Exception('Unknown BoltzNetwork value: $value'),
    };
  }
}
