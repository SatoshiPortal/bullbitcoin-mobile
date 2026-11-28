import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'support/open_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final reopen in [false, true]) {
    test(
      'revoked joined balance is not published while writes drain (reopen: $reopen)',
      () async {
        final directory = await Directory.systemTemp.createTemp('wallet-join-');
        final fixture = await openFreshInventory(directory);
        final inventory = fixture.inventory;
        addTearDown(() async {
          await inventory.close();
          await fixture.admission.close();
          await directory.delete(recursive: true);
        });
        final writeStarted = Completer<void>();
        final writeRelease = Completer<void>();
        final write = inventory.registerWallet(
          watchOnlyWallet('wpkh([01234567/84h/1h/0h])'),
          prepareProperties: (_) async {
            writeStarted.complete();
            await writeRelease.future;
            return const Ok(null);
          },
        );
        await writeStarted.future;
        final readStarted = Completer<void>();
        final readRelease = Completer<void>();
        final joined = inventory.readInSession(() async {
          readStarted.complete();
          await readRelease.future;
          return BigInt.from(7);
        });
        await readStarted.future;
        final locking = inventory.lock();
        if (reopen) expect(await inventory.resumeUnprotected(), isA<Err>());
        readRelease.complete();
        expect(await joined, isA<Err<BigInt, SecretFailure>>());
        writeRelease.complete();
        await write;
        expect(await locking, isTrue);
        if (reopen) expect(await inventory.resumeUnprotected(), isA<Ok>());
      },
    );
  }
}
