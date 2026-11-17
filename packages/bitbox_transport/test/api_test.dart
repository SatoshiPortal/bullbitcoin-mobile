import 'package:bitbox_transport/bitbox_transport.dart';
import 'package:bull_sdk/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => BullSdk.initMock(api: _UnusedApi()));

  tearDownAll(BullSdk.dispose);

  test('initializes on top of the SDK the host app already initialized', () {
    expect(BitBoxApi.initialize(), completes);
  });
}

class _UnusedApi implements BullSdkApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
