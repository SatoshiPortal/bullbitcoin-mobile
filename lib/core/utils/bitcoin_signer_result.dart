import 'dart:convert';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';

enum BitcoinSignerResultFormat { psbt, transaction }

const int maxBitcoinPsbtDecodedBytes = 2 * 1024 * 1024;
const int maxBitcoinPsbtTransportBytes = 3 * 1024 * 1024;

const _psbtMagic = <int>[0x70, 0x73, 0x62, 0x74, 0xff];

typedef ParsedBitcoinSignerResult = ({
  BitcoinSignerResultFormat format,
  String value,
});

ParsedBitcoinSignerResult parseBitcoinSignerResult(String result) {
  final value = result.trim();
  if (value.length > maxBitcoinPsbtTransportBytes) {
    throw const FormatException('Bitcoin signer result is too large');
  }
  try {
    final psbt = bdk.Psbt(psbtBase64: normalizeBitcoinPsbt(value));
    try {
      return (format: BitcoinSignerResultFormat.psbt, value: psbt.serialize());
    } finally {
      psbt.dispose();
    }
  } on Exception {
    try {
      final normalized = value.toLowerCase();
      final transaction = bdk.Transaction(
        transactionBytes: Uint8List.fromList(hex.decode(normalized)),
      );
      try {
        transaction.computeTxid();
        return (
          format: BitcoinSignerResultFormat.transaction,
          value: normalized,
        );
      } finally {
        transaction.dispose();
      }
    } on Exception {
      throw const FormatException('Unsupported Bitcoin signer result');
    }
  }
}

String normalizeBitcoinPsbt(String value) {
  if (value.length > maxBitcoinPsbtTransportBytes) {
    throw const FormatException('PSBT exceeds the maximum supported size');
  }
  final normalized = value.replaceAll(RegExp(r'\s'), '');
  if (normalized.length > maxBitcoinPsbtTransportBytes) {
    throw const FormatException('PSBT exceeds the maximum supported size');
  }

  final Uint8List decoded;
  try {
    decoded = base64.decode(normalized);
  } on FormatException {
    throw const FormatException('Invalid PSBT encoding');
  }
  return encodeBitcoinPsbtBytes(decoded);
}

String encodeBitcoinPsbtBytes(List<int> bytes) {
  if (bytes.length > maxBitcoinPsbtDecodedBytes) {
    throw const FormatException('PSBT exceeds the maximum supported size');
  }
  if (bytes.length < _psbtMagic.length ||
      !Iterable<int>.generate(
        _psbtMagic.length,
      ).every((index) => bytes[index] == _psbtMagic[index])) {
    throw const FormatException('Invalid PSBT data');
  }
  return base64.encode(bytes);
}

String decodeBitcoinPsbtFileBytes(List<int> bytes) {
  if (bytes.length > maxBitcoinPsbtTransportBytes) {
    throw const FormatException('PSBT file exceeds the maximum supported size');
  }
  if (bytes.length >= _psbtMagic.length &&
      Iterable<int>.generate(
        _psbtMagic.length,
      ).every((index) => bytes[index] == _psbtMagic[index])) {
    return encodeBitcoinPsbtBytes(bytes);
  }
  try {
    return normalizeBitcoinPsbt(utf8.decode(bytes));
  } on FormatException {
    throw const FormatException('Invalid PSBT file');
  }
}
