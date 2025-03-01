import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server.freezed.dart';

@freezed
class ElectrumServer with _$ElectrumServer {
  factory ElectrumServer({
    required String url,
    required Network network,
    @Default(null) String? socks5,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
  }) = _ElectrumServer;
  const ElectrumServer._();
}
