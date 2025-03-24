import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hex/hex.dart';

part 'recoverbull_wallet.freezed.dart';
part 'recoverbull_wallet.g.dart';

@JsonSerializable()
class HexConverter implements JsonConverter<List<int>, String> {
  const HexConverter();

  @override
  List<int> fromJson(String json) => HEX.decode(json);

  @override
  String toJson(List<int> object) => HEX.encode(object);
}

@freezed
class RecoverBullWallet with _$RecoverBullWallet {
  const factory RecoverBullWallet({
    @HexConverter() required List<int> seed,
    required WalletMetadata metadata,
  }) = _RecoverBullWallet;

  factory RecoverBullWallet.fromJson(Map<String, dynamic> json) =>
      _$RecoverBullWalletFromJson(json);
}
