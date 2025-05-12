import 'package:bb_mobile/_model/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'old_seed.freezed.dart';
part 'old_seed.g.dart';

@freezed
class Seed with _$Seed {
  const factory Seed({
    @Default('') String mnemonic,
    @Default('') String mnemonicFingerprint,
    required BBNetwork network,
    required List<Passphrase> passphrases,
  }) = _Seed;

  const Seed._();

  factory Seed.fromJson(Map<String, dynamic> json) => _$SeedFromJson(json);

  String getSeedStorageString() {
    return mnemonicFingerprint;
  }

  List<String> mnemonicList() {
    return mnemonic.split(' ');
  }

  Passphrase getPassphraseFromIndex(String sourceFingerprint) {
    return passphrases.firstWhere(
      (element) => element.sourceFingerprint == sourceFingerprint,
      orElse: () => Passphrase(sourceFingerprint: mnemonicFingerprint),
    );
  }
}

@freezed
class Passphrase with _$Passphrase {
  const factory Passphrase({
    @Default('') String passphrase,
    required String sourceFingerprint,
  }) = _Passphrase;
  const Passphrase._();

  factory Passphrase.fromJson(Map<String, dynamic> json) =>
      _$PassphraseFromJson(json);
}
