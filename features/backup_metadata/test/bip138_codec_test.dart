import 'dart:convert';
import 'dart:typed_data';

import 'package:backup_metadata/backup_metadata.dart';
import 'package:backup_metadata/setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart';

const _key =
    'tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba';
const _external = 'wpkh([d34db33f/84h/1h/0h]$_key/0/*)';
const _internal = 'wpkh([d34db33f/84h/1h/0h]$_key/1/*)';
const _codec = Bip138BackupMetadataCodec();

BackupWallet _wallet({String? label = 'Savings', bool watchOnly = false}) =>
    BackupWallet(
      network: BitcoinNetwork.testnet,
      scriptType: ScriptType.bip84,
      externalDescriptor: _external,
      internalDescriptor: _internal,
      watchOnly: watchOnly,
      label: label,
      birthday: DateTime.utc(2026, 11, 21),
    );

BackupGroup _group({
  String? secretReference = '01234567',
  List<String>? descriptors,
}) => BackupGroup(
  id: 'group',
  displayName: 'Group',
  network: BitcoinNetwork.testnet,
  bitcoinWalletIds: ['wallet'],
  liquidWalletIds: ['liquid'],
  bitcoinPublicDescriptors: descriptors ?? [_external, _internal],
  seedBackupVerified: true,
  wallets: [_wallet(watchOnly: secretReference == null)],
  secretReference: secretReference,
);

BackupContent _content({
  List<BackupDerivation> derivations = const [],
  String? label = 'Savings',
  bool watchOnly = false,
}) => BackupContent(
  labels: LabelsSnapshot(
    records: [
      BackupLabelRecord(
        chain: BackupLabelChain.bitcoin,
        type: BackupLabelType.tx,
        ref: 'aa' * 32,
        label: 'rent',
      ),
      BackupLabelRecord(
        chain: BackupLabelChain.bitcoin,
        type: BackupLabelType.output,
        ref: '${'bb' * 32}:1',
        spendable: false,
        walletId: 'wallet',
      ),
      BackupLabelRecord(
        chain: BackupLabelChain.liquid,
        type: BackupLabelType.addr,
        ref: 'lq1addr',
        label: 'liquid coffee',
        walletId: 'liquid',
      ),
    ],
    unattributedCount: 0,
    skippedCount: 0,
  ),
  wallets: [_wallet(label: label, watchOnly: watchOnly)],
  derivations: derivations,
);

const _children = [
  BackupDerivation(
    path: "128169'/32'/0'",
    application: 'hex',
    status: 'active',
    alias: 'one',
  ),
  BackupDerivation(
    path: "128169'/32'/4'",
    application: 'hex',
    status: 'revoked',
  ),
];

Future<Uint8List> _encrypt(BackupGroup group, BackupContent content) async {
  final prepared = (_codec.prepare(
    group,
    content,
  ) as Ok<PreparedBackup, BackupMetadataFailure>).value;
  return (await prepared.encrypt() as Ok<Uint8List, BackupMetadataFailure>)
      .value;
}

Future<BackupContent?> _decode(BackupGroup group, Uint8List bytes) async {
  final result = await _codec.decode(group, bytes);
  expect(result, isA<Ok<BackupContent?, BackupMetadataFailure>>());
  return (result as Ok<BackupContent?, BackupMetadataFailure>).value;
}

void main() {
  setUpAll(BullSdk.init);

  test(
    'a group round-trips labels, freezes, accounts and the registry',
    () async {
      final group = _group();
      final bytes = await _encrypt(group, _content(derivations: _children));
      final decoded = await _decode(group, bytes);

      expect(decoded, isNotNull);
      final records = decoded!.labels.records;
      expect(records, hasLength(3));
      final freeze = records.singleWhere((record) => record.spendable == false);
      expect(freeze.walletId, 'wallet');
      expect(freeze.type, BackupLabelType.output);
      final liquid = records.singleWhere(
        (record) => record.chain == BackupLabelChain.liquid,
      );
      expect((liquid.label, liquid.walletId), ('liquid coffee', 'liquid'));
      final wallet = decoded.wallets.single;
      expect(wallet.externalDescriptor, _external);
      expect(wallet.internalDescriptor, _internal);
      expect(wallet.label, 'Savings');
      expect(wallet.birthday, DateTime.utc(2026, 11, 21));
      expect(wallet.watchOnly, isFalse);
      expect(
        decoded.derivations.map(
          (child) => (child.path, child.status, child.alias),
        ),
        [
          ("128169'/32'/0'", 'active', 'one'),
          ("128169'/32'/4'", 'revoked', null),
        ],
      );
    },
  );

  test('the digest follows the content, not the order of its records', () {
    final group = _group();
    String digest(BackupContent content) => (_codec.prepare(
      group,
      content,
    ) as Ok<PreparedBackup, BackupMetadataFailure>).value.digest;
    final base = _content(derivations: _children);
    final reversed = BackupContent(
      labels: LabelsSnapshot(
        records: base.labels.records.reversed.toList(),
        unattributedCount: 0,
        skippedCount: 0,
      ),
      wallets: base.wallets,
      derivations: base.derivations.reversed.toList(),
    );
    expect(digest(reversed), digest(base));
    expect(digest(_content(label: 'Other')), isNot(digest(_content())));
    expect(digest(_content()), isNot(digest(base)));
  });

  test(
    'the decrypted plaintext holds a closed set of fields and no secret',
    () async {
      final group = _group();
      final bytes = await _encrypt(group, _content(derivations: _children));
      final items = (await bip138Decrypt(
        bytes: bytes,
        candidatePublicDescriptors: [_external, _internal],
      ))!;
      expect(items, hasLength(3));
      final text = items.map((item) => utf8.decode(item.bytes)).join('\n');
      expect(text, isNot(contains('prv')));
      expect(text, isNot(contains('mnemonic')));
      expect(text, isNot(contains('ct(')));
      expect(text, contains(_key));

      final vendor = items.singleWhere(
        (item) => item.contentType is Bip138ContentType_Vendor,
      );
      final document = jsonDecode(utf8.decode(vendor.bytes)) as Map;
      expect(
        document.keys,
        unorderedEquals([
          'v',
          'kind',
          'liquid',
          'attribution',
          'wallets',
          'derivations',
        ]),
      );
      expect(
        (document['wallets'] as List).single.keys,
        unorderedEquals([
          'network',
          'script',
          'external',
          'internal',
          'label',
          'birthday',
          'watch',
        ]),
      );
      expect(
        (document['derivations'] as List).first.keys,
        unorderedEquals(['path', 'application', 'status', 'alias']),
      );
      final container = jsonDecode(
        utf8.decode(
          items
              .singleWhere(
                (item) =>
                    item.contentType is Bip138ContentType_Bip &&
                    (item.contentType as Bip138ContentType_Bip).number == 139,
              )
              .bytes,
        ),
      ) as Map;
      expect(
        container.keys,
        unorderedEquals(['version', 'network', 'accounts']),
      );
    },
  );

  test('a file of another group, kind or network is not this group\'s', () async {
    final bytes = await _encrypt(_group(), _content());
    // Another account entirely cannot decrypt it.
    const other =
        'wpkh(xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6RpmZnd4aqWHHnM5UyKSsvyBgU61Xo1DJ8wYJfuTHfCzDdfJhT4)';
    expect(await _decode(_group(descriptors: [other]), bytes), isNull);
    // The same account as a watch-only group is a different file.
    expect(await _decode(_group(secretReference: null), bytes), isNull);
    final watch = await _encrypt(
      _group(secretReference: null),
      _content(watchOnly: true),
    );
    expect(await _decode(_group(), watch), isNull);
    expect(await _decode(_group(secretReference: null), watch), isNotNull);
  });

  test('a damaged or truncated envelope never decodes', () async {
    final group = _group();
    final bytes = await _encrypt(group, _content());
    final flipped = Uint8List.fromList(bytes)..[bytes.length - 3] ^= 1;
    final damaged = await _codec.decode(group, flipped);
    expect(damaged.fold((value) => value, (_) => null), isNull);
    final truncated = await _codec.decode(
      group,
      Uint8List.sublistView(bytes, 0, bytes.length ~/ 2),
    );
    expect(truncated.fold((value) => value, (_) => null), isNull);
  });

  test('a group without a public recipient, or with a private key, is refused', () {
    expect(
      _codec.prepare(_group(descriptors: [_external]), _content()),
      isA<Err<PreparedBackup, BackupMetadataFailure>>(),
      reason: 'the accounts do not match the recipients',
    );
    const private =
        'wpkh(tprv8ZgxMBicQKsPd4cSWHRBwJt5ZjFAq6mY2dP7wK4rWjYaXvNf5wB8m5nQ3Zk2cXrZ4Yk9T6bL1Vh7Q2c8dFgHj3KmNpQrStUvWxYz1A2B3C4D5E6F7G8/0/*)';
    expect(
      _codec.prepare(_group(descriptors: [private, private]), _content()),
      isA<Err<PreparedBackup, BackupMetadataFailure>>(),
    );
  });

  test('decoding revalidates what the envelope claims', () async {
    final group = _group();
    Future<Uint8List> forge(
      Map<String, Object?> Function(Map<String, Object?>) edit, {
      bool extraItem = false,
    }) async {
      final items = (await bip138Decrypt(
        bytes: await _encrypt(group, _content()),
        candidatePublicDescriptors: [_external, _internal],
      ))!;
      final forged = <Bip138Item>[
        for (final item in items)
          if (item.contentType is Bip138ContentType_Vendor)
            Bip138Item(
              contentType: item.contentType,
              bytes: Uint8List.fromList(
                utf8.encode(
                  jsonEncode(
                    edit(
                      (jsonDecode(utf8.decode(item.bytes)) as Map)
                          .cast<String, Object?>(),
                    ),
                  ),
                ),
              ),
            )
          else
            item,
        if (extraItem)
          Bip138Item(
            contentType: const Bip138ContentType.text(),
            bytes: Uint8List.fromList(utf8.encode('extra')),
          ),
      ];
      return bip138Encrypt(
        publicDescriptors: [_external, _internal],
        items: forged,
        padded: true,
      );
    }

    Future<void> expectRejected(Uint8List bytes) async {
      final result = await _codec.decode(group, bytes);
      expect(
        result.fold((value) => value, (_) => null),
        isNull,
        reason: 'neither content nor a partial restore',
      );
    }

    await expectRejected(await forge((doc) => {...doc, 'v': 3}));
    await expectRejected(await forge((doc) => {...doc, 'kind': 'other'}));
    await expectRejected(await forge((doc) => {...doc, 'wallets': []}));
    await expectRejected(await forge((doc) => {...doc, 'derivations': 'x'}));
    await expectRejected(
      await forge(
        (doc) => {
          ...doc,
          'wallets': [
            {
              ...(doc['wallets'] as List).single as Map,
              'external': 'wpkh(tprvSecret/0/*)',
            },
          ],
        },
      ),
    );
    await expectRejected(await forge((doc) => doc, extraItem: true));
  });
}
