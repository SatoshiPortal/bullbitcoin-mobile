import 'dart:convert' show base64, utf8;

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:ndef/ndef.dart' as ndef;

const _bitcoinNfcTypePrefix = 'urn:nfc:ext:';
const _bitcoinPsbtType = 'bitcoin.org:psbt';
const _bitcoinTxnType = 'bitcoin.org:txn';
const _bitcoinSha256Type = 'bitcoin.org:sha256';
const _jsonMimeType = 'application/json';

String? payloadFromNdefRecords(List<ndef.NDEFRecord> records) {
  if (records.isEmpty) return null;

  final bitcoinPayload = _payloadFromBitcoinExternalRecords(records);
  if (bitcoinPayload != null || _hasBitcoinPayloadRecord(records)) {
    return bitcoinPayload;
  }

  return _payloadFromRecord(records.last);
}

String? _payloadFromBitcoinExternalRecords(List<ndef.NDEFRecord> records) {
  final txnPayload = _externalPayloadForType(records, _bitcoinTxnType);
  if (txnPayload != null) {
    if (!_matchesSha256Checksum(records, txnPayload)) return null;
    return hex.encode(txnPayload);
  }

  final psbtPayload = _externalPayloadForType(records, _bitcoinPsbtType);
  if (psbtPayload != null) {
    if (!_matchesSha256Checksum(records, psbtPayload)) return null;
    return base64.encode(psbtPayload);
  }

  return null;
}

bool _hasBitcoinPayloadRecord(List<ndef.NDEFRecord> records) {
  return _hasExternalRecordForType(records, _bitcoinTxnType) ||
      _hasExternalRecordForType(records, _bitcoinPsbtType);
}

String? _payloadFromRecord(ndef.NDEFRecord record) {
  if (record is ndef.TextRecord) {
    final text = record.text;
    return text == null || text.isEmpty ? null : text;
  }

  if (record is ndef.ExternalRecord) {
    final payload = record.payload;
    if (payload == null || payload.isEmpty) return null;
    return hex.encode(payload);
  }

  if (record is ndef.MimeRecord && record.decodedType == _jsonMimeType) {
    final payload = record.payload;
    if (payload == null || payload.isEmpty) return null;

    try {
      return utf8.decode(payload);
    } on FormatException {
      return null;
    }
  }

  return null;
}

List<int>? _externalPayloadForType(List<ndef.NDEFRecord> records, String type) {
  for (final record in records.whereType<ndef.ExternalRecord>()) {
    if (_normalizedExternalType(record) != type) continue;

    final payload = record.payload;
    if (payload == null || payload.isEmpty) return null;
    return payload;
  }

  return null;
}

bool _hasExternalRecordForType(List<ndef.NDEFRecord> records, String type) {
  return records.whereType<ndef.ExternalRecord>().any(
    (record) => _normalizedExternalType(record) == type,
  );
}

String? _normalizedExternalType(ndef.ExternalRecord record) {
  final decodedType = record.decodedType;
  if (decodedType == null || decodedType.isEmpty) return null;

  if (decodedType.startsWith(_bitcoinNfcTypePrefix)) {
    return decodedType.substring(_bitcoinNfcTypePrefix.length);
  }

  return decodedType;
}

bool _matchesSha256Checksum(List<ndef.NDEFRecord> records, List<int> payload) {
  final expectedHash = _externalPayloadForType(records, _bitcoinSha256Type);
  if (expectedHash == null) return true;

  return _bytesEqual(expectedHash, sha256.convert(payload).bytes);
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;

  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }

  return true;
}
