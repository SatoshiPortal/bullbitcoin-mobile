import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed.freezed.dart';

@freezed
sealed class Seed with _$Seed {
  const Seed._();

  /// Bytes-based seed
  const factory Seed.bytes({
    required Uint8List bytes,
    required String masterFingerprint,
    String? bip85MasterSeedFingerprint,
  }) = BytesSeed;

  /// Mnemonic-based seed
  const factory Seed.mnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
    required Uint8List bytes,
    required String masterFingerprint,
    String? bip85MasterSeedFingerprint,
  }) = MnemonicSeed;

  String get hex => bytes.toHexString();
  bool get isBip85Derived =>
      bip85MasterSeedFingerprint != null &&
      bip85MasterSeedFingerprint!.isNotEmpty;
}
