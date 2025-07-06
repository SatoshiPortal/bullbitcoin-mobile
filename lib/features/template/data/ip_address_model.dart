import 'package:bb_mobile/features/template/domain/ip_address_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ip_address_model.freezed.dart';
part 'ip_address_model.g.dart';

@freezed
sealed class IpAddressModel with _$IpAddressModel {
  const factory IpAddressModel({
    required String ipAddr,
    required String userAgent,
    required String port,
    required String method,
    required String encoding,
    String? via,
    String? forwarded,
  }) = _IpAddressModel;
  const IpAddressModel._();

  factory IpAddressModel.fromJson(Map<String, dynamic> json) =>
      _$IpAddressModelFromJson(json);

  IpAddressEntity toEntity() {
    return IpAddressEntity(
      ipAddress: ipAddr,
      userAgent: userAgent,
      port: int.tryParse(port) ?? 80,
      method: RequestMethod.values.firstWhere(
        (m) => m.name.toLowerCase() == method.toLowerCase(),
        orElse: () => RequestMethod.get,
      ),
      supportedEncodings: _parseEncodings(encoding),
      forwardedChain: forwarded?.split(',') ?? <String>[],
      timestamp: DateTime.now(),
    );
  }

  List<EncodingType> _parseEncodings(String encodingStr) {
    final encodings = <EncodingType>[];
    final parts = encodingStr.split(',');
    for (final part in parts) {
      switch (part.trim().toLowerCase()) {
        case 'gzip':
          encodings.add(EncodingType.gzip);
        case 'deflate':
          encodings.add(EncodingType.deflate);
        case 'br':
          encodings.add(EncodingType.br);
        case 'zstd':
          encodings.add(EncodingType.zstd);
      }
    }
    return encodings;
  }
}
