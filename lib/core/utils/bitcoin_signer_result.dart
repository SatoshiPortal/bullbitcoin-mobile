import 'dart:convert';
import 'dart:typed_data';

const int maxBitcoinPsbtDecodedBytes = 2 * 1024 * 1024;
const int maxBitcoinPsbtTransportBytes = 3 * 1024 * 1024;

const _psbtMagic = <int>[0x70, 0x73, 0x62, 0x74, 0xff];

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
