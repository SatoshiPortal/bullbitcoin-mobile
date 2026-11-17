import 'dart:convert';
import 'dart:typed_data';

import '../bitcoin_transaction_decoder.dart';

/// Extracts only GLOBAL_UNSIGNED_TX from a bounded, native-reserialized PSBT. Native parsing owns the grammar; transaction decoding owns consensus fields. No input maps are parsed here.
Uint8List psbtUnsignedTransaction(String canonical) {
  if (canonical.isEmpty || canonical.length > maxEncodedBitcoinPsbtLength) {
    throw const FormatException('PSBT size');
  }
  final cursor = _GlobalCursor(base64Decode(canonical));
  if (!_same(cursor.take(5), const [0x70, 0x73, 0x62, 0x74, 0xff])) {
    throw const FormatException('PSBT magic');
  }
  Uint8List? unsigned;
  while (true) {
    final keySize = cursor.size();
    if (keySize == 0) break;
    final key = cursor.take(keySize);
    final valueSize = cursor.size();
    if (key.length == 1 && key[0] == 0) {
      if (unsigned != null ||
          valueSize == 0 ||
          valueSize > maxBitcoinTransactionBytes) {
        throw const FormatException('PSBT unsigned transaction');
      }
      unsigned = cursor.take(valueSize);
    } else {
      cursor.take(valueSize);
    }
  }
  return unsigned ?? (throw const FormatException('PSBT unsigned transaction'));
}

bool _same(List<int> a, List<int> b) =>
    a.length == b.length &&
    Iterable.generate(a.length).every((index) => a[index] == b[index]);

final class _GlobalCursor {
  final Uint8List _bytes;
  int _offset = 0;

  _GlobalCursor(this._bytes);

  Uint8List take(int length) {
    if (length < 0 || length > _bytes.length - _offset) {
      throw const FormatException('PSBT global bounds');
    }
    final bytes = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return bytes;
  }

  int size() {
    final tag = take(1)[0];
    if (tag < 0xfd) return tag;
    // A canonical 64-bit CompactSize is at least 2^32, larger than the entire bounded PSBT. Reject before attempting a slice or integer conversion.
    if (tag == 0xff) throw const FormatException('PSBT global size');
    final bytes = take(tag == 0xfd ? 2 : 4);
    final data = ByteData.sublistView(bytes);
    final value = tag == 0xfd
        ? data.getUint16(0, Endian.little)
        : data.getUint32(0, Endian.little);
    if (value < (tag == 0xfd ? 0xfd : 0x10000)) {
      throw const FormatException('PSBT noncanonical size');
    }
    return value;
  }
}
