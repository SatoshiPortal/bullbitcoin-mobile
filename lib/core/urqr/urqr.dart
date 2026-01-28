import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bs58check/bs58check.dart' as base58;
import 'package:cbor/cbor.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:ur/ur.dart';
import 'package:ur/ur_decoder.dart';
import 'package:ur/ur_encoder.dart';

class UrQrGenerator {
  static List<String> generatePsbtUr(String psbt, {int fragmentLength = 100}) {
    try {
      final psbtBytes = base64.decode(psbt);
      final cryptoPsbt = CryptoPsbt.fromPayload(psbtBytes);
      final ur = cryptoPsbt.toUR();
      final encoder = UREncoder(ur, fragmentLength);

      final parts = <String>[];
      while (!encoder.isComplete) {
        final part = encoder.nextPart();
        parts.add(part);
      }

      return parts;
    } catch (e) {
      log.severe(
        message: 'Failed to generate PSBT UR',
        error: e,
        trace: StackTrace.current,
      );
      return [];
    }
  }
}

class UrQrReader {
  URDecoder urDecoder = URDecoder();
  Object? decoded;
  String? _currentType;
  final Set<String> _processedQrCodes = <String>{};

  int get processedParts => urDecoder.processedPartsCount();
  int? get expectedParts => urDecoder.expectedPartCount();
  String? get currentType => _currentType;
  bool get isComplete => decoded != null;
  double get progress {
    if (_currentType != null) {
      return urDecoder.estimatedPercentComplete();
    }
    return decoded != null ? 1.0 : 0.0;
  }

  bool receive(String receivedData) {
    if (_processedQrCodes.contains(receivedData)) {
      return false;
    }

    _processedQrCodes.add(receivedData);

    try {
      final data = receivedData.toLowerCase();

      final String type = data.substring(
        data.indexOf(":") + 1,
        data.indexOf("/"),
      );

      final bool multipart = "/".allMatches(data).length > 1;

      Uint8List payload = Uint8List(0);
      if (!multipart) {
        payload = URDecoder.decode(data).cbor;
      } else {
        final success = urDecoder.receivePart(data);
        if (!success) {
          throw FailedToReceiveUrPart();
        }

        _currentType = type;

        if (urDecoder.isComplete()) {
          if (urDecoder.isSuccess()) {
            payload = (urDecoder.resultMessage() as UR).cbor;
          } else {
            throw UrDecodeFailed();
          }
        } else {
          return false;
        }
      }

      if (payload.isNotEmpty) {
        if (type == "crypto-hdkey") {
          decoded = CryptoHdKey.fromCbor(payload);
        } else if (type == "crypto-account") {
          decoded = CryptoAccount.fromCbor(payload);
        } else if (type == "crypto-psbt") {
          decoded = CryptoPsbt.fromCbor(payload);
        } else if (type == "bytes") {
          decoded = Binary.fromPayload(payload);
        } else {
          throw UnsupportedUrType(type);
        }
        return true;
      }
      throw EmptyPayload();
    } catch (e) {
      if (e is UrQrError) {
        rethrow;
      }
      // Convert unexpected errors to UrQrError
      throw UrQrError('Unexpected error processing UR data: $e');
    }
  }

  void reset() {
    urDecoder = URDecoder();
    decoded = null;
    _currentType = null;
    _processedQrCodes.clear();
  }
}

enum HdKeyNetwork { mainnet, testnet }

class CryptoHdKey {
  List<int>? keyData;
  List<int>? chainCode;
  HdKeyNetwork? network;
  int? parentFingerprint;
  List<Index>? keypath;

  String get path {
    final buffer = StringBuffer();
    for (final index in keypath!) {
      buffer.write('/${index.key}');
      if (index.hardened) {
        buffer.write('h');
      }
    }
    return buffer.toString();
  }

  String? get derivationPath {
    return 'm$path';
  }

  String? get xpub {
    if (keyData != null && chainCode != null && network != null) {
      final version = network == HdKeyNetwork.mainnet ? 0x0488b21e : 0x043587cf;
      return _generateXPub(
        keyData!,
        chainCode!,
        version,
        depth: keypath?.length ?? 0,
        parentFingerprint: parentFingerprint ?? 0,
        childNumber: keypath?.isNotEmpty == true ? keypath!.last.key : 0,
      );
    }
    return null;
  }

  CryptoHdKey({
    this.keyData,
    this.chainCode,
    this.network,
    this.parentFingerprint,
    this.keypath,
  });

  CryptoHdKey.fromCbor(Uint8List payload) {
    try {
      final map = cbor.decode(payload) as Map;

      keyData = (map[3] as CborList).cast<int>();
      chainCode = (map[4] as CborList).cast<int>();

      final networkData = map[5] as CborMap;
      final networkValue = (networkData[CborValue(2)] as CborSmallInt?)?.value;
      network = networkValue == 0 ? HdKeyNetwork.mainnet : HdKeyNetwork.testnet;
      parentFingerprint = (map[8] as CborSmallInt?)?.value;

      final pathData = map[6] as CborMap;
      final path = pathData[CborValue(1)] as CborList?;
      if (path != null) {
        keypath = [];
        for (int i = 0; i < path.length; i += 2) {
          keypath!.add(
            Index(
              (path[i] as CborSmallInt).value,
              (path[i + 1] as CborBool).value,
            ),
          );
        }
      }
    } catch (e) {
      throw InvalidCborData();
    }
  }

  CryptoHdKey.fromCborMap(Map map) {
    try {
      keyData = (map[3] as CborBytes).bytes;
      chainCode = (map[4] as CborBytes).bytes;

      if (map.containsKey(5)) {
        final networkData = map[5] as CborMap;
        network = (networkData[CborValue(2)] as CborSmallInt?)?.value == 0
            ? HdKeyNetwork.mainnet
            : HdKeyNetwork.testnet;
      } else {
        network = HdKeyNetwork.mainnet;
      }

      parentFingerprint = (map[8] as CborSmallInt?)?.value;

      final pathData = map[6] as CborMap;
      final path = pathData[CborValue(1)] as CborList?;
      if (path != null) {
        keypath = [];
        for (int i = 0; i < path.length; i += 2) {
          keypath!.add(
            Index(
              (path[i] as CborSmallInt).value,
              (path[i + 1] as CborBool).value,
            ),
          );
        }
      }
    } catch (e) {
      throw InvalidCborData();
    }
  }
}

class Index {
  int key;
  bool hardened;

  Index(this.key, this.hardened);
}

class Binary {
  String decoded = "";
  Uint8List payload;

  Binary.fromPayload(this.payload) {
    try {
      final cborData = cbor.decode(payload);
      final decodedString = String.fromCharCodes((cborData as CborBytes).bytes);

      if (decodedString.startsWith('psbt') ||
          decodedString.startsWith('PSBT')) {
        final cryptoPsbt = CryptoPsbt.fromCbor(payload);
        decoded = cryptoPsbt.base64Psbt;
      } else {
        try {
          final jsonData = json.decode(decodedString);
          decoded = json.encode(jsonData);
          if (jsonData is Map<String, dynamic>) {
            final descriptors = _parsePassportJsonDescriptors(jsonData);
            if (descriptors != null) {
              decoded = json.encode(descriptors);
            }
          }
        } catch (e) {
          decoded = decodedString;
        }
      }
    } catch (e) {
      throw InvalidCborData();
    }
  }

  @override
  String toString() {
    return decoded;
  }
}

class CryptoPsbt {
  dynamic decoded;
  Uint8List payload;

  CryptoPsbt.fromPayload(this.payload) {
    decoded = String.fromCharCodes(payload);
  }

  CryptoPsbt.fromCbor(this.payload) {
    try {
      final decodedData = cbor.decode(payload) as CborBytes;
      decoded = decodedData.bytes;
    } catch (e) {
      throw InvalidCborData();
    }
  }

  UR toUR() {
    final encoded = cbor.encode(CborBytes(payload));
    return UR('crypto-psbt', Uint8List.fromList(encoded));
  }

  @override
  String toString() {
    return base64Psbt;
  }

  String get base64Psbt => base64.encode(decoded as List<int>);
}

class CryptoAccount {
  List<int>? masterFingerprintBytes;
  List<CryptoHdKey>? hdKeys;

  CryptoAccount.fromCbor(Uint8List payload) {
    try {
      final rawMap = cbor.decode(payload) as Map;

      final map = <int, dynamic>{};
      for (final entry in rawMap.entries) {
        map[(entry.key as CborSmallInt).value] = entry.value;
      }

      if (map.containsKey(1)) {
        final fingerprintInt = (map[1] as CborSmallInt).value;
        masterFingerprintBytes = [
          (fingerprintInt >> 24) & 0xFF,
          (fingerprintInt >> 16) & 0xFF,
          (fingerprintInt >> 8) & 0xFF,
          fingerprintInt & 0xFF,
        ];
      } else {
        throw MissingMasterFingerprint();
      }

      if (map.containsKey(2)) {
        final outputsList = map[2] as CborList;
        hdKeys = [];

        for (int i = 0; i < outputsList.length; i++) {
          try {
            final rawOutput = outputsList[i] as CborMap;
            final output = <int, dynamic>{};
            for (final entry in rawOutput.entries) {
              output[(entry.key as CborSmallInt).value] = entry.value;
            }

            final hdKey = CryptoHdKey.fromCborMap(output);
            hdKeys!.add(hdKey);
          } catch (e) {
            throw FailedToParseOutput(i);
          }
        }
      } else {
        throw MissingOutputs();
      }
    } catch (e) {
      if (e is UrQrError) {
        rethrow;
      }
      throw InvalidCborData();
    }
  }

  String? get masterFingerprint {
    if (masterFingerprintBytes != null) {
      return masterFingerprintBytes!
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
    }
    return null;
  }

  List<CryptoHdKey> get allHdKeys => hdKeys ?? [];

  CryptoHdKey? get hdKey {
    final keys = hdKeys;
    if (keys == null || keys.isEmpty) return null;
    return keys.first;
  }

  CryptoHdKey? getHdKey(int index) {
    if (hdKeys != null && index < hdKeys!.length) {
      return hdKeys![index];
    }
    return null;
  }

  String? get derivationPath => hdKey?.derivationPath;

  String? get xpub => hdKey?.xpub;

  @override
  String toString() {
    if (masterFingerprint == null || hdKeys == null || hdKeys!.isEmpty) {
      return 'CryptoAccount(no key found)';
    }

    if (hdKeys!.length == 1) {
      final key = hdKeys!.first;
      if (key.derivationPath != null && key.xpub != null) {
        return Descriptor.fromStrings(
          fingerprint: masterFingerprint!,
          path: key.derivationPath!,
          xpub: key.xpub!,
        ).external;
      }
      return 'CryptoAccount(invalid key)';
    }

    final result = <String, String>{};
    for (final key in hdKeys!) {
      if (key.derivationPath == null || key.xpub == null) continue;
      final bipType = _derivationToBipType(key.derivationPath!);
      if (bipType != null) {
        result[bipType] = Descriptor.fromStrings(
          fingerprint: masterFingerprint!,
          path: key.derivationPath!,
          xpub: key.xpub!,
        ).external;
      }
    }

    if (result.isEmpty) {
      final key = hdKeys!.first;
      if (key.derivationPath != null && key.xpub != null) {
        return Descriptor.fromStrings(
          fingerprint: masterFingerprint!,
          path: key.derivationPath!,
          xpub: key.xpub!,
        ).external;
      }
      return 'CryptoAccount(no valid keys)';
    }

    return json.encode(result);
  }
}

String? _derivationToBipType(String path) {
  if (path.contains("/84'") || path.contains("/84h")) return 'bip84';
  if (path.contains("/49'") || path.contains("/49h")) return 'bip49';
  if (path.contains("/44'") || path.contains("/44h")) return 'bip44';
  return null;
}

String _generateXPub(
  List<int> keyData,
  List<int> chainCode,
  int version, {
  int depth = 0,
  int parentFingerprint = 0,
  int childNumber = 0,
}) {
  // Create the extended key data (78 bytes total)
  final extendedKey = Uint8List(78);

  // Version (4 bytes) - use the passed version parameter
  extendedKey[0] = (version >> 24) & 0xFF;
  extendedKey[1] = (version >> 16) & 0xFF;
  extendedKey[2] = (version >> 8) & 0xFF;
  extendedKey[3] = version & 0xFF;

  // Depth (1 byte)
  extendedKey[4] = depth;

  // Parent fingerprint (4 bytes)
  extendedKey[5] = (parentFingerprint >> 24) & 0xFF;
  extendedKey[6] = (parentFingerprint >> 16) & 0xFF;
  extendedKey[7] = (parentFingerprint >> 8) & 0xFF;
  extendedKey[8] = parentFingerprint & 0xFF;

  // Child number (4 bytes) - handle hardened keys
  final childNumberValue = childNumber >= 0x80000000
      ? childNumber
      : childNumber + 0x80000000;
  extendedKey[9] = (childNumberValue >> 24) & 0xFF;
  extendedKey[10] = (childNumberValue >> 16) & 0xFF;
  extendedKey[11] = (childNumberValue >> 8) & 0xFF;
  extendedKey[12] = childNumberValue & 0xFF;

  // Chain code (32 bytes)
  for (int i = 0; i < 32; i++) {
    extendedKey[13 + i] = chainCode[i];
  }

  // Key data (33 bytes)
  for (int i = 0; i < 33; i++) {
    extendedKey[45 + i] = keyData[i];
  }

  return base58.encode(extendedKey);
}

Map<String, String>? _parsePassportJsonDescriptors(Map<String, dynamic> data) {
  try {
    final result = <String, String>{};
    final String fingerprint = (data['xfp'] as String).trim().toLowerCase();

    for (final key in ['bip84', 'bip49', 'bip44']) {
      if (data.containsKey(key) && data[key] is Map) {
        final bip = data[key] as Map<String, dynamic>;
        final dynamic xpubDyn = bip['xpub'];
        final dynamic derivDyn = bip['deriv'];
        if (xpubDyn is String && derivDyn is String) {
          final String derivation = derivDyn.trim();
          final String xpub = xpubDyn.trim();
          result[key] = Descriptor.fromStrings(
            fingerprint: fingerprint,
            path: derivation,
            xpub: xpub,
          ).external;
        }
      }
    }
    return result.isEmpty ? null : result;
  } catch (_) {
    return null;
  }
}

class UrQrError implements Exception {
  final String message;

  UrQrError(this.message);

  @override
  String toString() => message;
}

class FailedToReceiveUrPart extends UrQrError {
  FailedToReceiveUrPart()
    : super('Failed to receive UR part during multipart decoding');
}

class UrDecodeFailed extends UrQrError {
  UrDecodeFailed() : super('UR decode failed - invalid or corrupted data');
}

class EmptyPayload extends UrQrError {
  EmptyPayload() : super('Empty payload received - no data to process');
}

class UnsupportedUrType extends UrQrError {
  final String type;

  UnsupportedUrType(this.type) : super('Unsupported UR type: $type');
}

class InvalidCborData extends UrQrError {
  InvalidCborData() : super('Invalid CBOR data format');
}

class MissingMasterFingerprint extends UrQrError {
  MissingMasterFingerprint()
    : super('No master fingerprint found in crypto account');
}

class MissingOutputs extends UrQrError {
  MissingOutputs() : super('No outputs found in crypto account');
}

class FailedToParseOutput extends UrQrError {
  final int index;

  FailedToParseOutput(this.index)
    : super('Failed to parse output $index in crypto account');
}
