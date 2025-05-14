import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'old_seed.freezed.dart';
part 'old_seed.g.dart';

@freezed
abstract class OldSeed with _$OldSeed {
  const factory OldSeed({
    @Default('') String mnemonic,
    @Default('') String mnemonicFingerprint,
    required OldBBNetwork network,
    required List<OldPassphrase> passphrases,
  }) = _Seed;

  const OldSeed._();

  factory OldSeed.fromJson(Map<String, dynamic> json) =>
      _$OldSeedFromJson(json);

  String getSeedStorageString() {
    return mnemonicFingerprint;
  }

  List<String> mnemonicList() {
    return mnemonic.split(' ');
  }

  OldPassphrase getPassphraseFromIndex(String sourceFingerprint) {
    return passphrases.firstWhere(
      (element) => element.sourceFingerprint == sourceFingerprint,
      orElse: () => OldPassphrase(sourceFingerprint: mnemonicFingerprint),
    );
  }
}

@freezed
abstract class OldPassphrase with _$OldPassphrase {
  const factory OldPassphrase({
    @Default('') String passphrase,
    required String sourceFingerprint,
  }) = _OldPassphrase;
  const OldPassphrase._();

  factory OldPassphrase.fromJson(Map<String, dynamic> json) =>
      _$OldPassphraseFromJson(json);
}
