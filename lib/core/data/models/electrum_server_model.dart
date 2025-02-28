import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server_model.freezed.dart';
part 'electrum_server_model.g.dart';

@freezed
class ElectrumServerModel with _$ElectrumServerModel {
  const ElectrumServerModel._();

  factory ElectrumServerModel({
    required String url,
    String? socks5,
    required int retry,
    int? timeout,
    required int stopGap,
    required bool validateDomain,
  }) = _ElectrumServerModel;

  factory ElectrumServerModel.fromJson(Map<String, dynamic> json) =>
      _$ElectrumServerModelFromJson(json);
}
