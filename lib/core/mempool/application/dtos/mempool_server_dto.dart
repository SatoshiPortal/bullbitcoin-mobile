import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';

class MempoolServerDto {
  final String url;
  final bool isCustom;
  final bool isTestnet;
  final bool isLiquid;

  MempoolServerDto({
    required this.url,
    required this.isCustom,
    required this.isTestnet,
    required this.isLiquid,
  });

  factory MempoolServerDto.fromEntity(MempoolServer entity) {
    return MempoolServerDto(
      url: entity.url,
      isCustom: entity.isCustom,
      isTestnet: entity.isTestnet,
      isLiquid: entity.isLiquid,
    );
  }

  String get fullUrl => 'https://$url';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MempoolServerDto &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          isCustom == other.isCustom &&
          isTestnet == other.isTestnet &&
          isLiquid == other.isLiquid;

  @override
  int get hashCode =>
      url.hashCode ^
      isCustom.hashCode ^
      isTestnet.hashCode ^
      isLiquid.hashCode;

  @override
  String toString() =>
      'MempoolServerDto(url: $url, isCustom: $isCustom, isTestnet: $isTestnet, isLiquid: $isLiquid)';
}
