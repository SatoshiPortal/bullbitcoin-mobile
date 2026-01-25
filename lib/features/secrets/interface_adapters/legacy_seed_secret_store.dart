import 'dart:convert';

import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/application/ports/legacy_seed_secret_store_port.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Implementation that reads legacy seeds stored in the old format.
/// Legacy seeds are stored directly by fingerprint (no prefix) with the old JSON structure.
/// This allows users to access seeds even if migration failed or legacy code is removed.
class LegacySecretStore implements LegacySecretStorePort {
  final FlutterSecureStorage _flutterSecureStorage;
  final SecretCryptoPort _secretCrypto;

  LegacySecretStore({
    required FlutterSecureStorage flutterSecureStorage,
    required SecretCryptoPort secretCrypto,
  }) : _flutterSecureStorage = flutterSecureStorage,
       _secretCrypto = secretCrypto;

  @override
  Future<List<Secret>> loadAll() async {
    try {
      final allEntries = await _flutterSecureStorage.readAll();

      // Top-level function for isolate processing
      @pragma('vm:entry-point')
      List<Secret> parseLegacySeedsInIsolate(Map<String, String> allEntries) {
        final secrets = <Secret>[];

        for (final entry in allEntries.entries) {
          try {
            final value = entry.value;
            if (value.isEmpty) continue;

            // Try to parse as old seed JSON
            final json = jsonDecode(value) as Map<String, dynamic>;

            // Check if this looks like an old seed (has mnemonic and mnemonicFingerprint)
            if (!json.containsKey('mnemonic') ||
                !json.containsKey('mnemonicFingerprint')) {
              continue;
            }

            final mnemonic = json['mnemonic'] as String;
            final mnemonicWords = mnemonic.split(' ');

            // Check if this seed has passphrases
            if (json.containsKey('passphrases') &&
                json['passphrases'] is List) {
              final passphrases = json['passphrases'] as List;
              final processedPassphrases = <String>{};

              for (final passphraseData in passphrases) {
                if (passphraseData is Map<String, dynamic> &&
                    passphraseData.containsKey('passphrase')) {
                  final passphrase = passphraseData['passphrase'] as String;

                  // Deduplicate passphrases within this mnemonic entry
                  if (processedPassphrases.contains(passphrase)) {
                    continue;
                  }
                  processedPassphrases.add(passphrase);

                  final passphraseObj = passphrase.isEmpty
                      ? null
                      : Passphrase(passphrase);
                  final fingerprint = _secretCrypto.getFingerprintFromMnemonic(
                    mnemonicWords: MnemonicWords(mnemonicWords),
                    passphrase: passphraseObj,
                  );

                  secrets.add(
                    MnemonicSecret(
                      words: MnemonicWords(mnemonicWords),
                      passphrase: passphraseObj,
                      fingerprint: fingerprint,
                    ),
                  );
                }
              }

              // If no passphrases were processed, add the base mnemonic
              if (processedPassphrases.isEmpty) {
                final fingerprint = _secretCrypto.getFingerprintFromMnemonic(
                  mnemonicWords: MnemonicWords(mnemonicWords),
                );
                secrets.add(
                  MnemonicSecret(
                    fingerprint: fingerprint,
                    words: MnemonicWords(mnemonicWords),
                  ),
                );
              }
            } else {
              // No passphrases array, just add the base mnemonic
              final fingerprint = _secretCrypto.getFingerprintFromMnemonic(
                mnemonicWords: MnemonicWords(mnemonicWords),
              );
              secrets.add(
                MnemonicSecret(
                  fingerprint: fingerprint,
                  words: MnemonicWords(mnemonicWords),
                  passphrase: null,
                ),
              );
            }
          } catch (e) {
            // Skip entries that aren't valid old seeds
            continue;
          }
        }

        return secrets;
      }

      // Parse entries in isolate to avoid blocking UI
      return await compute(parseLegacySeedsInIsolate, allEntries);
    } catch (e) {
      // If reading fails entirely, return empty list rather than throwing
      return [];
    }
  }
}
