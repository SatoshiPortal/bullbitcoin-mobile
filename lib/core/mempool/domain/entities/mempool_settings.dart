import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';

class MempoolSettings {
  final MempoolServerNetwork _network;
  final bool _useForFeeEstimation;

  MempoolSettings._({
    required MempoolServerNetwork network,
    required bool useForFeeEstimation,
  })  : _network = network,
        _useForFeeEstimation = useForFeeEstimation;

  factory MempoolSettings.create({
    required MempoolServerNetwork network,
    bool useForFeeEstimation = true,
  }) {
    return MempoolSettings._(
      network: network,
      useForFeeEstimation: useForFeeEstimation,
    );
  }

  factory MempoolSettings.existing({
    required MempoolServerNetwork network,
    required bool useForFeeEstimation,
  }) {
    return MempoolSettings._(
      network: network,
      useForFeeEstimation: useForFeeEstimation,
    );
  }

  MempoolServerNetwork get network => _network;
  bool get useForFeeEstimation => _useForFeeEstimation;

  MempoolSettings updateUseForFeeEstimation(bool value) {
    return MempoolSettings._(
      network: _network,
      useForFeeEstimation: value,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MempoolSettings &&
          runtimeType == other.runtimeType &&
          _network == other._network &&
          _useForFeeEstimation == other._useForFeeEstimation;

  @override
  int get hashCode => _network.hashCode ^ _useForFeeEstimation.hashCode;

  @override
  String toString() =>
      'MempoolSettings(network: $_network, useForFeeEstimation: $_useForFeeEstimation)';
}
