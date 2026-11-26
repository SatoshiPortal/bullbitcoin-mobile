import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:ark/src/data/ark_writer_lock.dart';
import 'package:primitives/primitives.dart';

Future<void> main(List<String> args) async {
  final lock = ArkWriterLock.acquire('${args[0]}/lock');
  if (lock case Err()) {
    exitCode = 9;
    return;
  }
  final held = (lock as Ok<ArkWriterLock, ArkWalletFailure>).value;
  if (args[1] == 'crash') {
    final store = ArkStore.open('${args[0]}/state', create: true);
    store.saveOperation(
      ArkOperation(
        id: 'admitted-before-death',
        kind: ArkOperationKind.payment,
        status: ArkOperationStatus.admitted,
        chainSource: Uri.parse('http://localhost'),
        configGeneration: 1,
      ),
      'review',
      evidence: {'txid': 'public-evidence'},
    );
    // Simulate death without Dart finally/close. SQLite FULL committed the row.
    exit(23);
  }
  stdout.writeln('held');
  await stdout.flush();
  await stdin.transform(utf8.decoder).first;
  held.release();
}
