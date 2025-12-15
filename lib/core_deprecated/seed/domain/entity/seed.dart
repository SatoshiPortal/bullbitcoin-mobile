import 'package:bb_mobile/core_deprecated/utils/uint_8_list_x.dart';
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
  }) = BytesSeed;

  /// Mnemonic-based seed
  const factory Seed.mnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
    required Uint8List bytes,
    required String masterFingerprint,
  }) = MnemonicSeed;

  String get hex => bytes.toHexString();
}
