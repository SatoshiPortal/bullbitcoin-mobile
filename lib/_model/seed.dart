// ignore_for_file: constant_identifier_names
import 'package:bb_mobile/_model/wallet2.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed.freezed.dart';
part 'seed.g.dart';

// {
//   network_fingerprint: Seed,
// }
@freezed
class Seed with _$Seed {
  const factory Seed({
    @Default('') String mnemonic,
    @Default('') String fingerprint,
    required BBNetwork network,
    required List<Passphrase> passphraseWallets,
  }) = _Seed;
  const Seed._();

  factory Seed.fromJson(Map<String, dynamic> json) => _$SeedFromJson(json);

  String getSeedStorageString() {
    return fingerprint;
  }

  List<String> mnemonicList() {
    return mnemonic.split(' ');
  }
}

@freezed
class Passphrase with _$Passphrase {
  const factory Passphrase({
    @Default('') String passphrase,
    required String fingerprint,
  }) = _Passphrase;
  const Passphrase._();

  factory Passphrase.fromJson(Map<String, dynamic> json) => _$PassphraseFromJson(json);
}
