// Local recovery harness. Words arrive on stdin, never in argv or logs.
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:bb_mobile/features/portable_backup/data/backup_password_material.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3 || !['encrypt', 'decrypt'].contains(args[0])) {
    stderr.writeln(
      'Usage: fvm dart run tools/portable_backup_crypt.dart encrypt|decrypt INPUT OUTPUT',
    );
    exitCode = 64;
    return;
  }
  final words = stdin.readLineSync();
  if (words == null) {
    stderr.writeln('The 12-word backup password is required on stdin.');
    exitCode = 64;
    return;
  }
  try {
    final output = File(args[2]);
    if (await output.exists()) {
      stderr.writeln('Output already exists.');
      exitCode = 73;
      return;
    }
    final encrypt = args[0] == 'encrypt';
    final limit = encrypt
        ? RecoverBullEncryption.maxPlaintextBytes
        : RecoverBullEncryption.maxCiphertextBytes;
    final input = BytesBuilder(copy: false);
    await for (final bytes in File(args[1]).openRead()) {
      if (input.length + bytes.length > limit) {
        throw const RecoverBullEncryptionException();
      }
      input.add(bytes);
    }
    final material = BackupPasswordMaterial.parse(words);
    const codec = RecoverBullEncryption();
    final result = encrypt
        ? await material.encrypt(codec, input.takeBytes())
        : await material.decrypt(codec, input.takeBytes());
    await output.writeAsBytes(result, flush: true);
  } on RecoverBullEncryptionException {
    stderr.writeln('Invalid encrypted file, key or size.');
    exitCode = 1;
  } on InvalidBackupPasswordException {
    stderr.writeln('Invalid 12-word backup password.');
    exitCode = 1;
  } on FileSystemException {
    stderr.writeln('Could not read input or write output.');
    exitCode = 1;
  }
}
