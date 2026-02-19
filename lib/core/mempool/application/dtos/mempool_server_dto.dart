import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_status.dart';

class MempoolServerDto {
  final String url;
  final bool isCustom;
  final bool isTestnet;
  final bool isLiquid;
  final bool enableSsl;
  final MempoolServerStatus status;

  MempoolServerDto({
    required this.url,
    required this.isCustom,
    required this.isTestnet,
    required this.isLiquid,
    this.enableSsl = true,
    this.status = MempoolServerStatus.unknown,
  });

  factory MempoolServerDto.fromEntity(MempoolServer entity) {
    return MempoolServerDto(
      url: entity.url,
      isCustom: entity.isCustom,
      isTestnet: entity.isTestnet,
      isLiquid: entity.isLiquid,
      enableSsl: entity.enableSsl,
    );
  }

  String get fullUrl => enableSsl ? 'https://$url' : 'http://$url';

  MempoolServerDto copyWith({
    String? url,
    bool? isCustom,
    bool? isTestnet,
    bool? isLiquid,
    bool? enableSsl,
    MempoolServerStatus? status,
  }) {
    return MempoolServerDto(
      url: url ?? this.url,
      isCustom: isCustom ?? this.isCustom,
      isTestnet: isTestnet ?? this.isTestnet,
      isLiquid: isLiquid ?? this.isLiquid,
      enableSsl: enableSsl ?? this.enableSsl,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MempoolServerDto &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          isCustom == other.isCustom &&
          isTestnet == other.isTestnet &&
          isLiquid == other.isLiquid &&
          enableSsl == other.enableSsl &&
          status == other.status;

  @override
  int get hashCode =>
      url.hashCode ^
      isCustom.hashCode ^
      isTestnet.hashCode ^
      isLiquid.hashCode ^
      enableSsl.hashCode ^
      status.hashCode;

  @override
  String toString() =>
      'MempoolServerDto(url: $url, isCustom: $isCustom, isTestnet: $isTestnet, isLiquid: $isLiquid, enableSsl: $enableSsl, status: $status)';
}
