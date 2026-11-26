import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/src/data/read/native_frame_source.dart';
import 'package:sync/sync.dart';

void main() {
  test('a mapping failure needs repair only after the LWK status conflict', () {
    expect(
      mappingFailure(lwk.LwkError(msg: 'UpdateOnDifferentStatus { .. }')),
      isA<SyncNeedsRepairFailure>(),
    );
    expect(
      mappingFailure(lwk.LwkError(msg: 'Unexpected end of file')),
      isA<SyncStorageFailure>(),
    );
    expect(mappingFailure(const FormatException()), isA<SyncStorageFailure>());
  });
}
