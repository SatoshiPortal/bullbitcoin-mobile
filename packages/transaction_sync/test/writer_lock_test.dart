import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/src/write/writer_lock.dart';

final _key = WalletKey(id: 'lock-test', network: LiquidNetwork.testnet);

void _holder((String, SendPort) args) async {
  final commands = ReceivePort();
  final acquired = WriterLock.acquire(args.$1, _key);
  switch (acquired) {
    case Err():
      args.$2.send('busy');
      commands.close();
    case Ok(:final value):
      args.$2.send(commands.sendPort);
      await commands.first;
      value.release();
      args.$2.send('released');
  }
}

void main() {
  late Directory directory;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('writer-lock-');
  });
  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  test('writer then reader: worker excludes parent hydration', () async {
    final messages = ReceivePort();
    final iterator = StreamIterator(messages);
    final isolate = await Isolate.spawn(_holder, (
      directory.path,
      messages.sendPort,
    ));
    addTearDown(() {
      isolate.kill(priority: Isolate.immediate);
      messages.close();
    });
    expect(await iterator.moveNext(), isTrue);
    final command = iterator.current as SendPort;
    final watch = Stopwatch()..start();
    final blocked = WriterLock.acquire(directory.path, _key);
    expect(blocked, isA<Err<WriterLock, TransactionSyncFailure>>());
    expect((blocked as Err).failure, isA<TransactionSyncBusyFailure>());
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    command.send('release');
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, 'released');
    final acquired = WriterLock.acquire(directory.path, _key) as Ok;
    (acquired.value as WriterLock).release();
    await iterator.cancel();
  });

  test('reader then writer: parent hydration excludes worker', () async {
    final reader = WriterLock.acquire(directory.path, _key) as Ok;
    final messages = ReceivePort();
    await Isolate.spawn(_holder, (directory.path, messages.sendPort));
    expect(await messages.first, 'busy');
    (reader.value as WriterLock).release();
    messages.close();
  });

  test(
    'kill holder fails closed until process exit (sqlite3 finalizer pin)',
    () async {
      final messages = ReceivePort();
      final exited = ReceivePort();
      final isolate = await Isolate.spawn(_holder, (
        directory.path,
        messages.sendPort,
      ), onExit: exited.sendPort);
      expect(await messages.first, isA<SendPort>());
      isolate.kill(priority: Isolate.immediate);
      await exited.first;
      final blocked = WriterLock.acquire(directory.path, _key) as Err;
      expect(blocked.failure, isA<TransactionSyncBusyFailure>());
      messages.close();
      exited.close();
    },
  );

  test('network is part of lock identity', () {
    final first = WriterLock.acquire(directory.path, _key) as Ok;
    final second =
        WriterLock.acquire(
              directory.path,
              WalletKey(id: _key.id, network: LiquidNetwork.mainnet),
            )
            as Ok;
    (first.value as WriterLock).release();
    (second.value as WriterLock).release();
  });
}
