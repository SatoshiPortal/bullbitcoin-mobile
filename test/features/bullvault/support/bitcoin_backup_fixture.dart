import 'dart:typed_data';

import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_codec.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

import 'bip138_prototype_fixture.dart';

Uint8List backupPush(List<int> bytes) {
  final length = ByteData(2)..setUint16(0, bytes.length, Endian.little);
  return Uint8List.fromList([
    0x6a,
    0x4d,
    ...length.buffer.asUint8List(),
    ...bytes,
  ]);
}

Uint8List backupTransaction(
  Bip138PrototypeFixture fixture,
  List<int> payload, {
  bool includeMarkers = true,
  List<Uint8List> extraScripts = const [],
}) {
  final scripts = [
    backupPush(payload),
    ...extraScripts,
    if (includeMarkers)
      for (final signer in fixture.signers)
        BitcoinBackupCodec.discovery(
          DescriptorBackupKey.parse(signer.accountKey.xpub),
          BitcoinBackupNetwork.regtest,
        ).script,
  ];
  List<int> compact(int n) => n < 253 ? [n] : [253, n & 255, n >> 8];
  return Uint8List.fromList([
    2,
    0,
    0,
    0,
    1,
    ...List.filled(32, 1),
    0,
    0,
    0,
    0,
    0,
    254,
    255,
    255,
    255,
    scripts.length,
    for (var i = 0; i < scripts.length; i++) ...[
      if (i == 0) ...List.filled(8, 0) else ...[232, 3, 0, 0, 0, 0, 0, 0],
      ...compact(scripts[i].length),
      ...scripts[i],
    ],
    0,
    0,
    0,
    0,
  ]);
}

String backupTxid(Uint8List raw) {
  final tx = bdk.Transaction(transactionBytes: raw);
  try {
    final id = tx.computeTxid();
    try {
      return id.toString();
    } finally {
      id.dispose();
    }
  } finally {
    tx.dispose();
  }
}
