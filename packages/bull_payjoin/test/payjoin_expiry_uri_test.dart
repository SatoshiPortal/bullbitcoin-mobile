import 'dart:typed_data';

import 'package:bull_payjoin/src/engine/pdk_payjoin_datasource.dart';
import 'package:payjoin/payjoin.dart' as pj;
import 'package:test/test.dart';

final _ohttpKeys = pj.OhttpKeys.decode(
  bytes: Uint8List.fromList([
    0x01,
    0x00,
    0x16,
    0x04,
    0x52,
    0x73,
    0xda,
    0xa8,
    0xf6,
    0x4c,
    0xdf,
    0x80,
    0x8f,
    0x1e,
    0x94,
    0x03,
    0x98,
    0x09,
    0xf6,
    0x47,
    0xfc,
    0x21,
    0xca,
    0x68,
    0xb2,
    0xbd,
    0x31,
    0xe7,
    0x30,
    0xa9,
    0xc5,
    0x7d,
    0xf3,
    0x68,
    0x84,
    0xb2,
    0xe7,
    0x82,
    0x6e,
    0x2f,
    0xa1,
    0xad,
    0x2b,
    0x9f,
    0x23,
    0x88,
    0x15,
    0x76,
    0x5a,
    0xa6,
    0x7b,
    0x1f,
    0x56,
    0xcc,
    0x72,
    0xc6,
    0x69,
    0x83,
    0x40,
    0x69,
    0x89,
    0x86,
    0x87,
    0x80,
    0xee,
    0x59,
    0x9b,
    0x1f,
    0x00,
    0x04,
    0x00,
    0x01,
    0x00,
    0x03,
  ]),
);

const _expiredBip21 =
    'bitcoin:2N47mmrWXsNBvQR6k78hWJoTji57zXwNcU7?pjos=0&pj=HTTPS://PAYJO.IN/TXJCGKTKXLUUZ%23EX1WKV8CEC-OH1QYPM59NK2LXXS4890SUAXXYT25Z2VAPHP0X7YEYCJXGWAG6UG9ZU6NQ-RK1Q0DJS3VVDXWQQTLQ8022QGXSX7ML9PHZ6EDSF6AKEWQG758JPS2EV';

// ORIGINAL_PSBT from payjoin-test-utils, used instead of the unavailable
// test-only FFI originalPsbt() export in the locally cached native library.
const _originalPsbt =
    'cHNidP8BAHMCAAAAAY8nutGgJdyYGXWiBEb45Hoe9lWGbkxh/6bNiOJdCDuDAAAAAAD+////AtyVuAUAAAAAF6kUHehJ8GnSdBUOOv6ujXLrWmsJRDCHgIQeAAAAAAAXqRR3QJbbz0hnQ8IvQ0fptGn+votneofTAAAAAAEBIKgb1wUAAAAAF6kU3k4ekGHKWRNbA1rV5tR5kEVDVNCHAQcXFgAUx4pFclNVgo1WWAdN1SYNX8tphTABCGsCRzBEAiB8Q+A6dep+Rz92vhy26lT0AjZn4PRLi8Bf9qoB/CMk0wIgP/Rj2PWZ3gEjUkTlhDRNAQ0gXwTO7t9n+V14pZ6oljUBIQMVmsAaoNWHVMS02LfTSe0e388LNitPa1UQZyOihY+FFgABABYAFEb2Giu6c4KO5YW0pfw3lGp9jMUUAAA=';

void main() {
  test('receiver expiration is encoded in the BIP77 endpoint fragment', () {
    final persister = InMemoryJsonReceiverSessionPersister();
    final receiver = pj.ReceiverBuilder(
      address: 'tb1q6d3a2w975yny0asuvd9a67ner4nks58ff0q8g4',
      directory: 'https://directory.example',
      ohttpKeys: _ohttpKeys,
    ).withExpiration(expirationSecs: 3600).build().save(persister: persister);

    final bip21 = Uri.parse(receiver.pjUri().asString());
    final endpoint = Uri.parse(bip21.queryParameters['pj']!);

    expect(endpoint.fragment, contains('EX1'));
    expect(endpoint.fragment, contains('OH1'));
    expect(endpoint.fragment, contains('RK1'));
    expect(bip21.toString(), contains('%23EX1'));
  });

  test('sender rejects the official expired BIP77 vector locally', () {
    final payjoin = pj.Uri.parse(uri: _expiredBip21).checkPjSupported();
    final sender = pj.SenderBuilder(psbt: _originalPsbt, uri: payjoin)
        .buildRecommended(minFeeRateSatPerKwu: 1000)
        .save(persister: InMemoryJsonSenderSessionPersister());

    expect(
      () => sender.createV2PostRequest(ohttpRelay: 'https://relay.example'),
      throwsA(
        isA<pj.CreateRequestException>().having(
          (exception) => exception.isExpired(),
          'isExpired',
          isTrue,
        ),
      ),
    );
  });
}
