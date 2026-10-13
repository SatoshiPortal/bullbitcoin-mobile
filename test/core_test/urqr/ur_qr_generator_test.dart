import 'package:bb_mobile/core/urqr/urqr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes text as a decodable bytes UR', () {
    final parts = UrQrGenerator.generateBytesUr(
      'wallet registration',
      fragmentLength: 10,
    );
    final reader = UrQrReader();

    for (final part in parts) {
      reader.receive(part);
    }

    expect(reader.decoded.toString(), 'wallet registration');
  });
}
