// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'cold_card.freezed.dart';
part 'cold_card.g.dart';

@freezed
class ColdCard with _$ColdCard {
  factory ColdCard({
    String? chain,
    String? xpub,
    String? xfp,
    int? account,
    ColdWallet? bip49,
    ColdWallet? bip44,
    ColdWallet? bip84,
  }) = _ColdCard;
  const ColdCard._();

  factory ColdCard.fromJson(Map<String, dynamic> json) => _$ColdCardFromJson(json);

  // String? bip84Policy() => bip84 == null
  //     ? null
  //     : 'pk([${xfp!.toLowerCase()}/84h/${(chain == 'XTN') ? "1h" : "0h"}/${account}h}]${bip84!.xpub}/*)';

  // String? bip49Policy() => bip49 == null
  //     ? null
  //     : 'pk([${xfp!.toLowerCase()}/49h/${(chain == 'XTN') ? "1h" : "0h"}/${account}h}]${bip49!.xpub}/*)';

  // String? bip44Policy() => bip44 == null
  //     ? null
  //     : 'pk([${xfp!.toLowerCase()}/44h/${(chain == 'XTN') ? "1h" : "0h"}/${account}h}]${bip44!.xpub}/*)';

  bool isTestNet() => chain == 'XTN';
}

@freezed
class ColdWallet with _$ColdWallet {
  factory ColdWallet({
    String? xpub,
    String? first,
    String? deriv,
    String? xfp,
    String? name,
    @JsonKey(name: '_pub') String? sPub,
  }) = _ColdWallet;
  const ColdWallet._();

  factory ColdWallet.fromJson(Map<String, dynamic> json) => _$ColdWalletFromJson(json);
}
