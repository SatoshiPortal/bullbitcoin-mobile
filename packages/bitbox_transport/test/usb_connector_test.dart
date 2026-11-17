import 'dart:async';
import 'dart:collection';

import 'package:bitbox_transport/bitbox_transport.dart';
import 'package:bull_sdk/src/rust/frb_generated.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('bitbox_flutter');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final connector = UsbConnector();
  final queues = _Queues();

  setUpAll(() {
    BullSdk.initMock(api: queues);
  });

  setUp(() {
    queues.outgoing.clear();
    queues.incoming.clear();
  });

  tearDownAll(BullSdk.dispose);

  tearDown(() {
    connector.stop();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('sends a complete request without overlapping USB transfers', (
    tester,
  ) async {
    queues.outgoing.addAll([
      Uint8List.fromList([1]),
      Uint8List.fromList([2]),
    ]);
    final firstWrite = Completer<void>();
    final calls = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      if (call.method == 'sendData' && calls.length == 1) {
        await firstWrite.future;
      }
      return call.method == 'receiveData' ? Uint8List(0) : null;
    });

    connector.start(deviceSerial: 'device');
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, ['sendData']);
    firstWrite.complete();
    await tester.pump();
    expect(calls, ['sendData', 'sendData', 'receiveData']);
    expect(queues.incoming, isEmpty);
    connector.stop();
  });

  testWidgets('discards an old read after stopping and reconnecting', (
    tester,
  ) async {
    final oldRead = Completer<Uint8List>();
    var reads = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (reads++ == 0) return oldRead.future;
      return Uint8List.fromList([2]);
    });
    connector.start(deviceSerial: 'old');
    await tester.pump(const Duration(milliseconds: 20));
    connector.stop();
    connector.start(deviceSerial: 'new');
    await tester.pump(const Duration(milliseconds: 200));
    expect(reads, 1);
    oldRead.complete(Uint8List.fromList([1]));
    await tester.pump();
    expect(queues.incoming, isEmpty);
    await tester.pump(const Duration(milliseconds: 20));
    expect(queues.incoming.single.$1, 'new');
    expect(queues.incoming.single.$2, [2]);
    connector.stop();
  });

  testWidgets('stops after a native failure and can reconnect', (tester) async {
    var reads = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      reads++;
      if (reads == 1) throw PlatformException(code: 'RECEIVE_ERROR');
      return Uint8List.fromList([1]);
    });
    connector.start(deviceSerial: 'device');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(seconds: 1));
    expect(reads, 1);
    connector.start(deviceSerial: 'device');
    await tester.pump(const Duration(milliseconds: 20));
    expect(queues.incoming.single.$1, 'device');
    expect(queues.incoming.single.$2, [1]);
    connector.stop();
  });
}

class _Queues implements BullSdkApi {
  final outgoing = Queue<Uint8List>();
  final incoming = <(String, List<int>)>[];

  @override
  Uint8List? bitboxApiGetUsbWriteDataWrapper({required String serialNumber}) =>
      outgoing.isEmpty ? null : outgoing.removeFirst();

  @override
  void bitboxApiSetUsbReadDataWrapper({
    required String serialNumber,
    required List<int> data,
  }) {
    incoming.add((serialNumber, data));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
