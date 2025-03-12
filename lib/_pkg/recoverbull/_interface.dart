import 'dart:convert';
import 'dart:math';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_model/wallet_sensitive_data.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:bip85/bip85.dart' as bip85;
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

abstract class IRecoverbullManager {
  /// Encrypts a list of backups using BIP85 derivation
  Future<(({String key, BullBackup backup})?, Err?)> createEncryptedBackup({
    required List<WalletSensitiveData> wallets,
    required List<String> mnemonic,
    required String network,
  }) async {
    if (wallets.isEmpty) return (null, Err('No backups provided'));

    try {
      final plaintext = json.encode(wallets.map((i) => i.toJson()).toList());

      final randomIndex = _deriveRandomIndex();
      final derivationPath = "m/1608'/0'/$randomIndex";

      final (derived, err) =
          await deriveBackupKey(mnemonic, network, derivationPath);
      if (derived == null) {
        debugPrint(err.toString());
        return (null, Err('Failed to derive backup key'));
      }

      final backup = BackupService.createBackup(
        secret: utf8.encode(plaintext),
        backupKey: derived,
      );

      final mapBackup = backup.toMap();
      mapBackup['path'] = derivationPath;

      final backupWithPath = BullBackup.fromMap(mapBackup);

      return ((key: HEX.encode(derived), backup: backupWithPath), null);
    } catch (e) {
      return (null, Err('Encryption failed: $e'));
    }
  }

  /// Decrypts an encrypted backup using the provided key
  Future<(List<WalletSensitiveData>?, Err?)> restoreEncryptedBackup({
    required BullBackup backup,
    required List<int> backupKey,
  }) async {
    try {
      final plaintext = BackupService.restoreBackup(
        backup: backup,
        backupKey: backupKey,
      );

      final decodedJson = jsonDecode(plaintext) as List;
      final backups = decodedJson
          .map(
            (item) =>
                WalletSensitiveData.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      return (backups, null);
    } catch (e) {
      return (null, Err('Decryption failed: $e'));
    }
  }

  int _deriveRandomIndex() {
    final random = Uint8List(4);
    final secureRandom = Random.secure();
    for (int i = 0; i < 4; i++) {
      random[i] = secureRandom.nextInt(256);
    }
    final randomIndex =
        ByteData.view(random.buffer).getUint32(0, Endian.little) & 0x7FFFFFFF;

    return randomIndex;
  }

  Future<(List<int>?, Err?)> deriveBackupKey(
    List<String> mnemonic,
    String network,
    String derivationPath,
  ) async {
    try {
      final descriptorSecretKey = await DescriptorSecretKey.create(
        network: BBNetwork.fromString(network).toBdkNetwork(),
        mnemonic: await Mnemonic.fromString(mnemonic.join(' ')),
      );

      final key = bip85
          .derive(
            xprv: descriptorSecretKey.toString().split('/*').first,
            path: derivationPath,
          )
          .sublist(0, 32);
      return (key, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  // Abstract methods to be implemented by concrete classes
  Future<(String?, Err?)> saveEncryptedBackup({
    required BullBackup backup,
    String backupFolder = defaultBackupPath,
  });

  (BullBackup?, Err?) loadEncryptedBackup({required String file}) {
    try {
      final backup = BullBackup.fromJson(file);
      return (backup, null);
    } catch (e) {
      debugPrint('Failed to decode backup: $e');
      return (null, Err('Failed to decode backup'));
    }
  }

  Future<(String?, Err?)> removeEncryptedBackup({required String path});
}

extension ToUserDisplay on KeyServiceException {
  /// Returns true if this exception represents a rate limiting error
  bool get isRateLimited => code == 429;

  /// Returns true if this exception represents an authentication error
  bool get isAuthenticationError => code == 401;

  /// Returns true if this exception represents a validation error
  bool get isValidationError => code == 400;

  /// Returns true if this exception represents a duplicate key error
  bool get isDuplicateKey => code == 403;

  /// Gets how long to wait before retrying (in minutes), or 0 if unknown
  int get waitTimeInMinutes => cooldownInMinutes ?? 0;

  /// Gets a user-friendly error message based on server error codes and messages
  String get appMessage {
    if (isRateLimited) {
      // Status Code 429: "Too many attempts"
      return 'Too many attempts. Please try again after $waitTimeInMinutes minutes.';
    } else if (isAuthenticationError) {
      // Status Code 401: "Invalid identifier/authentication_key"
      return 'Invalid credentials provided. Please check your identifier and password.';
    } else if (isValidationError) {
      // Status Code 400: Various validation errors
      if (message?.contains('not 256 bits HEX hashes') ?? false) {
        return 'Invalid data format provided. The identifier or authentication key is not properly formatted.';
      } else if (message?.contains('encrypted_secret is empty') ?? false) {
        return 'Secret cannot be empty. Please provide a secret to store.';
      } else if (message?.contains('base64') ?? false) {
        return 'Invalid data encoding. The encrypted secret must be base64 encoded.';
      } else if (message?.contains('exceeds the limit') ?? false) {
        return 'Secret is too large. Please provide a smaller secret.';
      }
      return 'Invalid data. Please check your request parameters.';
    } else if (isDuplicateKey) {
      // Status Code 403: Duplicate entry (no specific message from server)
      return 'This key already exists.';
    } else {
      // Unknown errors
      switch (code) {
        case 500:
          return 'Server error. Please try again later.';
        case 503:
          return 'Service unavailable. Please try again later.';
        default:
          return message ?? 'An unknown error occurred.';
      }
    }
  }

  /// Comprehensive error code explanation
  String get errorCodeExplanation {
    switch (code) {
      case 400:
        return 'Bad Request: The server cannot process the request due to invalid data.';
      case 401:
        return 'Unauthorized: The provided authentication credentials are invalid.';
      case 403:
        return 'Forbidden: You are not allowed to perform this operation (duplicate key).';
      case 429:
        return 'Too Many Requests: You have exceeded the rate limit. Try again later.';
      case 500:
        return 'Internal Server Error: The server encountered an unexpected condition.';
      default:
        return '';
    }
  }

  /// Returns a user-friendly display message
  String toUserDisplay() {
    if (isRateLimited && cooldownInMinutes != null) {
      return 'Too many attempts. Please wait for $waitTimeInMinutes minutes before trying again.';
    }
    return appMessage;
  }

  /// Returns a detailed technical error for logging
  String toDetailedError() {
    return '${code != null ? "Error: ($code):" : ""} $message\n'
        '${errorCodeExplanation.isNotEmpty ? "Error Type: $errorCodeExplanation\n" : ""}'
        '${requestedAt != null ? "Requested at: $requestedAt\n" : ""}'
        '${cooldownInMinutes != null ? "Cooldown: $cooldownInMinutes minutes" : ""}';
  }
}
