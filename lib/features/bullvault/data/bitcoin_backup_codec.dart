import 'dart:typed_data';

import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_parser.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';

abstract final class BitcoinBackupCodec {
  static bdk.Network nativeNetwork(BitcoinBackupNetwork network) =>
      bdk.Network.values.byName(network.name);

  static void checkNetwork(
    DescriptorBackupKey key,
    BitcoinBackupNetwork network,
  ) {
    if (key.isTestnet != (network != BitcoinBackupNetwork.bitcoin)) {
      throw const FormatException('Account and chain disagree');
    }
  }

  static ({String address, Uint8List script}) discovery(
    DescriptorBackupKey key,
    BitcoinBackupNetwork network,
  ) {
    checkNetwork(key, network);
    final descriptor = bdk.Descriptor(
      descriptor: 'wpkh(${key.xpub}/0/0)',
      networkKind: key.isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main,
    );
    try {
      final address = descriptor.deriveAddress(
        index: 0,
        network: nativeNetwork(network),
      );
      try {
        final script = address.scriptPubkey();
        try {
          return (address: address.toString(), script: script.toBytes());
        } finally {
          script.dispose();
        }
      } finally {
        address.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  }

  static BitcoinBackupPublication prepare(
    String source,
    BitcoinBackupNetwork network,
  ) {
    final parsed = DescriptorBackupParser.parseDescriptor(source);
    final keys = <DescriptorBackupKey>[];
    for (final expression in parsed.keys) {
      final key = DescriptorBackupKey.parse(expression.xpub);
      checkNetwork(key, network);
      if (!keys.any(key.sameAccount)) keys.add(key);
    }
    if (keys.length != 3) {
      throw const FormatException('Three cosigners required');
    }
    return BitcoinBackupPublication(
      parsed.descriptor,
      Bip138Codec().encode(
        parsed.descriptor,
        keys.map((key) => key.xOnly).toList(),
      ),
      keys.map((key) => discovery(key, network).address).toList(),
    );
  }

  /// One data push after OP_RETURN. Parsing script bytes avoids mistaking opcode
  /// bytes inside a push for instructions, and rejects trailing executable data.
  static Uint8List? payload(Uint8List script) {
    if (script.length < 2 || script[0] != 0x6a) return null;
    var offset = 2;
    final opcode = script[1];
    final int size;
    if (opcode <= 75) {
      size = opcode;
    } else if (opcode == 76 && script.length >= 3) {
      size = script[2];
      offset = 3;
    } else if (opcode == 77 && script.length >= 4) {
      size = ByteData.sublistView(script).getUint16(2, Endian.little);
      offset = 4;
    } else if (opcode == 78 && script.length >= 6) {
      size = ByteData.sublistView(script).getUint32(2, Endian.little);
      offset = 6;
    } else {
      throw const FormatException('Invalid OP_RETURN push');
    }
    if (size > Bip138Codec.maxBytes || script.length != offset + size) {
      throw const FormatException('Invalid backup length');
    }
    final bytes = Uint8List.sublistView(script, offset);
    return bytes.length >= 6 &&
            hex.encode(bytes.sublist(0, 6)) == '424950313338'
        ? bytes
        : null;
  }

  static List<BitcoinBackupCandidate> recover(
    Uint8List raw,
    String txid,
    int height,
    DescriptorBackupKey key,
    BitcoinBackupNetwork network,
  ) {
    final marker = discovery(key, network).script;
    final markerHex = hex.encode(marker);
    final transaction = bdk.Transaction(transactionBytes: raw);
    final outputs = transaction.output();
    try {
      final computed = transaction.computeTxid();
      try {
        if (computed.toString() != txid) {
          throw const FormatException('Transaction mismatch');
        }
      } finally {
        computed.dispose();
      }
      if (!outputs.any(
        (output) => hex.encode(output.scriptPubkey.toBytes()) == markerHex,
      )) {
        return const []; // History also contains transactions spending the marker.
      }
      final candidates = <BitcoinBackupCandidate>[];
      var rejectedPayload = false;
      for (var i = 0; i < outputs.length; i++) {
        try {
          final bytes = payload(outputs[i].scriptPubkey.toBytes());
          if (bytes == null) continue;
          for (final content in Bip138Codec().decode(bytes, key.xOnly)) {
            final parsed = DescriptorBackupParser.parseDescriptor(content);
            final keys = parsed.keys
                .map((k) => DescriptorBackupKey.parse(k.xpub))
                .toList();
            if (!keys.any(key.sameAccount)) {
              throw const FormatException('Account mismatch');
            }
            for (final candidateKey in keys) {
              checkNetwork(candidateKey, network);
            }
            candidates.add(
              BitcoinBackupCandidate(
                descriptor: parsed.descriptor,
                txid: txid,
                outputIndex: i,
                reportedHeight: height,
              ),
            );
          }
        } on Exception {
          rejectedPayload = true;
        }
      }
      if (candidates.isEmpty && rejectedPayload) {
        throw const FormatException('No valid backup payload');
      }
      return candidates;
    } finally {
      for (final output in outputs) {
        output.scriptPubkey.dispose();
        output.value.dispose();
      }
      transaction.dispose();
    }
  }
}
