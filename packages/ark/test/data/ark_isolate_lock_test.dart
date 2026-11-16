import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_writer_lock.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

Future<void> holder((String, SendPort) args) async {
  final commands = ReceivePort();
  final result = ArkWriterLock.acquire(args.$1);
  if (result case Ok(:final value)) {
    args.$2.send(commands.sendPort);
    await commands.first;
    value.release();
    args.$2.send('released');
  } else {
    args.$2.send('busy');
  }
  commands.close();
}

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('ark-isolate-'));
  tearDown(() => temp.deleteSync(recursive: true));
  test('killed holder retains native exclusion until process exit', () async {
    final messages = ReceivePort();
    final exited = ReceivePort();
    final isolate = await Isolate.spawn(holder, (
      '${temp.path}/lock',
      messages.sendPort,
    ), onExit: exited.sendPort);
    addTearDown(() {
      isolate.kill(priority: Isolate.immediate);
      messages.close();
      exited.close();
    });
    expect(await messages.first, isA<SendPort>());
    isolate.kill(priority: Isolate.immediate);
    await exited.first;
    final result = ArkWriterLock.acquire('${temp.path}/lock');
    if (result case Ok(:final value)) value.release();
    expect(result, isA<Err<ArkWriterLock, ArkWalletFailure>>());
    expect((result as Err).failure, isA<ArkWriterBusyFailure>());
  });
  test('normal admitted completion explicitly releases both Dart and native handles', () async {
    final messages = ReceivePort();
    final iterator = StreamIterator(messages);
    final isolate = await Isolate.spawn(holder, (
      '${temp.path}/lock',
      messages.sendPort,
    ));
    addTearDown(() {
      isolate.kill(priority: Isolate.immediate);
      messages.close();
    });
    expect(await iterator.moveNext(), isTrue);
    final command = iterator.current as SendPort;
    expect(ArkWriterLock.acquire('${temp.path}/lock'), isA<Err>());
    command.send('finish');
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, 'released');
    final result = ArkWriterLock.acquire('${temp.path}/lock');
    expect(result, isA<Ok>());
    (result as Ok<ArkWriterLock, ArkWalletFailure>).value.release();
    await iterator.cancel();
  });
}
