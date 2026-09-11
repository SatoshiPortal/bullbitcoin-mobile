import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_codec.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_parser.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bip138_prototype_fixture.dart';
import '../support/bitcoin_backup_fixture.dart';

void main() {
  final fixture = Bip138PrototypeFixture();
  final keys = fixture.signers
      .map((s) => DescriptorBackupKey.parse(s.accountKey.xpub))
      .toList();
  const network = BitcoinBackupNetwork.regtest;

  test(
    'one OP_RETURN and three fixed markers recover identical payload under all keys',
    () {
      final publication = BitcoinBackupCodec.prepare(
        fixture.descriptor(),
        network,
      );
      final raw = backupTransaction(fixture, publication.payload);
      final txid = backupTxid(raw);
      final tx = bdk.Transaction(transactionBytes: raw);
      final outputs = tx.output();
      try {
        expect(outputs.length, 4);
        expect(
          BitcoinBackupCodec.payload(outputs.first.scriptPubkey.toBytes()),
          publication.payload,
        );
      } finally {
        for (final o in outputs) {
          o.scriptPubkey.dispose();
          o.value.dispose();
        }
        tx.dispose();
      }
      for (final key in keys) {
        final recovered = BitcoinBackupCodec.recover(
          raw,
          txid,
          102,
          key,
          network,
        );
        expect(recovered.single.descriptor, publication.descriptor);
        expect(recovered.single.txid, txid);
      }
    },
  );

  test('a malformed additional OP_RETURN cannot hide a valid backup', () {
    final publication = BitcoinBackupCodec.prepare(
      fixture.descriptor(),
      network,
    );
    final raw = backupTransaction(
      fixture,
      publication.payload,
      extraScripts: [
        Uint8List.fromList([0x6a, 0x4d]),
      ],
    );
    final recovered = BitcoinBackupCodec.recover(
      raw,
      backupTxid(raw),
      1,
      keys.first,
      network,
    );
    expect(recovered.single.descriptor, publication.descriptor);
  });

  test('first receiving address ignores supplied origin and change suffix', () {
    final input = 'wpkh(${keys.first.xpub}/1/*)';
    final parsed = DescriptorBackupParser.inputKey(input);
    expect(
      BitcoinBackupCodec.discovery(parsed, network).address,
      BitcoinBackupCodec.discovery(keys.first, network).address,
    );
  });

  test('revault policies differ while discovery addresses remain fixed', () {
    final first = BitcoinBackupCodec.prepare(fixture.descriptor(), network);
    final next = BitcoinBackupCodec.prepare(
      fixture.descriptor(generation: 1),
      network,
    );
    expect(first.descriptor, isNot(next.descriptor));
    expect(first.addresses, next.addresses);
    expect(first.payload, isNot(next.payload));
  });

  test(
    'wrong txid, missing marker, corrupt ciphertext and wrong chain reject',
    () {
      final publication = BitcoinBackupCodec.prepare(
        fixture.descriptor(),
        network,
      );
      final raw = backupTransaction(fixture, publication.payload);
      expect(
        () => BitcoinBackupCodec.recover(raw, '0' * 64, 1, keys.first, network),
        throwsFormatException,
      );
      final unrelated = backupTransaction(
        fixture,
        publication.payload,
        includeMarkers: false,
      );
      expect(
        BitcoinBackupCodec.recover(
          unrelated,
          backupTxid(unrelated),
          1,
          keys.first,
          network,
        ),
        isEmpty,
      );
      final altered = Uint8List.fromList(publication.payload)..last ^= 1;
      final tampered = backupTransaction(fixture, altered);
      expect(
        () => BitcoinBackupCodec.recover(
          tampered,
          backupTxid(tampered),
          1,
          keys.first,
          network,
        ),
        throwsFormatException,
      );
      expect(
        () => BitcoinBackupCodec.discovery(
          keys.first,
          BitcoinBackupNetwork.bitcoin,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'OP_RETURN rejects truncated, trailing and oversized pushes; unrelated data is ignored',
    () {
      for (final bytes in [
        [0x6a, 0x4d],
        [0x6a, 0x4c, 8, 0],
        [0x6a, 0x4e, 255, 255, 255, 255],
        [0x6a, 1, 1, 0],
      ]) {
        expect(
          () => BitcoinBackupCodec.payload(Uint8List.fromList(bytes)),
          throwsFormatException,
        );
      }
      expect(
        BitcoinBackupCodec.payload(Uint8List.fromList([0x6a, 1, 0])),
        isNull,
      );
      expect(
        BitcoinBackupCodec.payload(Uint8List.fromList([0, 20, 1])),
        isNull,
      );
    },
  );

  test(
    'export two public synthetic test-chain publication fixtures',
    () {
      const destination = String.fromEnvironment('BACKUP_FIXTURE');
      final publicationNetwork = BitcoinBackupNetwork.values.byName(
        const String.fromEnvironment(
          'DISTRIBUTED_NETWORK',
          defaultValue: 'regtest',
        ),
      );
      expect(
        publicationNetwork,
        isIn([BitcoinBackupNetwork.regtest, BitcoinBackupNetwork.testnet4]),
      );
      final generations = [
        for (var i = 0; i < 2; i++)
          (() {
            final publication = BitcoinBackupCodec.prepare(
              fixture.descriptor(generation: i),
              publicationNetwork,
            );
            final parsed = BdkFacade.parsePublicTwoPathDescriptor(
              descriptor: publication.descriptor,
              isTestnet: true,
            );
            String address(String source) {
              final descriptor = bdk.Descriptor(
                descriptor: source,
                networkKind: bdk.NetworkKind.test,
              );
              try {
                final a = descriptor.deriveAddress(
                  index: 0,
                  network: BitcoinBackupCodec.nativeNetwork(publicationNetwork),
                );
                try {
                  return a.toString();
                } finally {
                  a.dispose();
                }
              } finally {
                descriptor.dispose();
              }
            }

            return {
              'descriptor': publication.descriptor,
              'payload': hex.encode(publication.payload),
              'addresses': publication.addresses,
              'receive': address(parsed.externalDescriptor),
              'change': address(parsed.internalDescriptor),
            };
          })(),
      ];
      final wifs = [
        for (var i = 0; i < 3; i++)
          Bip32Keys.fromSeed(
            Uint8List.fromList(List.filled(32, i + 71)),
            network: NetworkType(
              wif: 0xef,
              bip32: Bip32Type(public: 0x043587cf, private: 0x04358394),
            ),
          ).derivePath("m/48'/1'/0'/2'/0/0").toWIF(),
      ];
      File(destination).writeAsStringSync(
        jsonEncode({
          'profile':
              'distributed-backup-public-${publicationNetwork.name}-fixture-1',
          'xpubs': keys.map((k) => k.xpub).toList(),
          'markerTestWifs': wifs,
          'generations': generations,
        }),
      );
    },
    skip: const String.fromEnvironment('BACKUP_FIXTURE').isEmpty,
  );
}
