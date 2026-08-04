import 'dart:convert' show base64, utf8;
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/nfc_payload_parser.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndef/ndef.dart' as ndef;

void main() {
  group('payloadFromNdefRecords', () {
    test('returns text from the last record', () {
      final records = [
        ndef.TextRecord(text: 'first'),
        ndef.TextRecord(text: 'second'),
      ];

      expect(payloadFromNdefRecords(records), 'second');
    });

    test('returns hex from the last external record by default', () {
      final record = ndef.ExternalRecord(
        decodedType: 'example.com:data',
        payload: Uint8List.fromList([0, 15, 255]),
      );

      expect(payloadFromNdefRecords([record]), '000fff');
    });

    test('returns UTF-8 text from an application/json MIME record', () {
      const json = '{"xfp":"f23f9fd2"}';
      final record = ndef.MimeRecord(
        decodedType: 'application/json',
        payload: Uint8List.fromList(utf8.encode(json)),
      );

      expect(payloadFromNdefRecords([record]), json);
    });

    test('returns null for malformed application/json MIME payloads', () {
      final record = ndef.MimeRecord(
        decodedType: 'application/json',
        payload: Uint8List.fromList([0xff]),
      );

      expect(payloadFromNdefRecords([record]), isNull);
    });

    test('returns hex from a bitcoin transaction external record', () {
      final txnPayload = Uint8List.fromList([2, 0, 0, 0, 255]);
      final records = [
        ndef.TextRecord(text: 'Signed Transaction'),
        ndef.ExternalRecord(
          decodedType: 'bitcoin.org:txid',
          payload: Uint8List.fromList(List.filled(32, 1)),
        ),
        ndef.ExternalRecord(
          decodedType: 'bitcoin.org:txn',
          payload: txnPayload,
        ),
        ndef.ExternalRecord(
          decodedType: 'bitcoin.org:sha256',
          payload: Uint8List.fromList(sha256.convert(txnPayload).bytes),
        ),
      ];

      expect(payloadFromNdefRecords(records), '02000000ff');
    });

    test('returns base64 from a bitcoin PSBT external record', () {
      final psbtPayload = Uint8List.fromList([112, 115, 98, 116, 255, 1]);
      final records = [
        ndef.ExternalRecord(
          decodedType: 'bitcoin.org:sha256',
          payload: Uint8List.fromList(sha256.convert(psbtPayload).bytes),
        ),
        ndef.ExternalRecord(
          decodedType: 'bitcoin.org:psbt',
          payload: psbtPayload,
        ),
        ndef.TextRecord(text: 'Partly signed PSBT'),
      ];

      expect(payloadFromNdefRecords(records), base64.encode(psbtPayload));
    });

    test('normalizes bitcoin external record URN prefixes', () {
      final txnPayload = Uint8List.fromList([2, 0, 0, 0, 255]);
      final record = ndef.ExternalRecord(
        decodedType: 'urn:nfc:ext:bitcoin.org:txn',
        payload: txnPayload,
      );

      expect(payloadFromNdefRecords([record]), '02000000ff');
    });

    test('returns null when bitcoin checksum does not match', () {
      final txnPayload = Uint8List.fromList([2, 0, 0, 0, 255]);
      final records = [
        ndef.ExternalRecord(
          decodedType: 'bitcoin.org:sha256',
          payload: Uint8List.fromList(List.filled(32, 2)),
        ),
        ndef.ExternalRecord(
          decodedType: 'bitcoin.org:txn',
          payload: txnPayload,
        ),
      ];

      expect(payloadFromNdefRecords(records), isNull);
    });

    test('returns null for empty records', () {
      expect(payloadFromNdefRecords([]), isNull);
    });
  });

  group('pushTxUriFromNdefRecords', () {
    const pushTxUri =
        'https://coldcard.com/pushtx#t=AgAAAAABAA&c=x0PSGeD-JzE7Vg';

    test('returns the uri record verbatim, fragment included', () {
      final record = ndef.UriRecord()..iriString = pushTxUri;

      expect(pushTxUriFromNdefRecords([record]), pushTxUri);
    });

    test('finds a uri record that is not the last record', () {
      final records = [
        ndef.UriRecord()..iriString = pushTxUri,
        ndef.TextRecord(text: 'trailing note'),
      ];

      expect(pushTxUriFromNdefRecords(records), pushTxUri);
    });

    test('returns null when no record carries a uri', () {
      final records = [ndef.TextRecord(text: 'not a uri')];

      expect(pushTxUriFromNdefRecords(records), isNull);
    });

    test('returns null for empty records', () {
      expect(pushTxUriFromNdefRecords([]), isNull);
    });

    test('leaves the bitcoin payload path untouched', () {
      final txnPayload = Uint8List.fromList([2, 0, 0, 0, 255]);
      final records = [
        ndef.UriRecord()..iriString = pushTxUri,
        ndef.ExternalRecord(
          decodedType: 'bitcoin.org:txn',
          payload: txnPayload,
        ),
      ];

      expect(payloadFromNdefRecords(records), '02000000ff');
      expect(pushTxUriFromNdefRecords(records), pushTxUri);
    });
  });
}
