import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/metadata_backup.dart';
import 'package:secrets/storage.dart';

import 'support/open_inventory.dart';

final _parent = Fingerprint('01234567');

RecordedDerivation _hex(
  int index, {
  String status = 'active',
  String? alias,
  Fingerprint? parent,
  int length = 32,
}) => RecordedDerivation(
  path: "128169'/$length'/$index'",
  parentFingerprint: (parent ?? _parent).hex,
  application: 'hex',
  status: status,
  alias: alias,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late SecretsInventory inventory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bip85-merge-');
    final opened = await openFreshInventory(directory);
    inventory = opened.inventory;
    admission = opened.admission;
    valueOf(await inventory.registerWallet(localWallet('one', _parent.hex)));
  });

  tearDown(() async {
    await inventory.close();
    await admission.close();
    await directory.delete(recursive: true);
  });

  Future<List<RecordedDerivation>> stored() async =>
      valueOf(await inventory.listDerivations());

  test(
    'gaps and revocations survive and the next index stays above them',
    () async {
      final report = valueOf(
        await inventory.mergeDerivationArchive(
          parent: _parent,
          records: [
            _hex(0),
            _hex(3, status: 'revoked', alias: 'old'),
            _hex(7),
          ],
        ),
      );
      expect((report.added, report.updated, report.unchanged), (3, 0, 0));
      expect((await stored()).map((record) => record.index), [0, 3, 7]);
      final next = valueOf(
        await inventory.reserveHexDerivation(parent: _parent, length: 32),
      );
      expect(next.index, 8);
      expect(
        (await stored()).singleWhere((record) => record.index == 3).status,
        'revoked',
      );
    },
  );

  test(
    'an existing row never moves toward active and keeps its alias',
    () async {
      final local = valueOf(
        await inventory.reserveHexDerivation(
          parent: _parent,
          length: 32,
          alias: 'mine',
        ),
      );
      valueOf(await inventory.setDerivationActive(local, active: false));
      final other = valueOf(
        await inventory.reserveHexDerivation(parent: _parent, length: 32),
      );
      final report = valueOf(
        await inventory.mergeDerivationArchive(
          parent: _parent,
          records: [
            _hex(0, alias: 'theirs'),
            _hex(1, status: 'revoked', alias: 'x'),
          ],
        ),
      );
      expect((report.added, report.updated, report.unchanged), (0, 1, 1));
      final rows = {for (final row in await stored()) row.index: row};
      expect(rows[0]?.status, 'revoked');
      expect(rows[0]?.alias, 'mine');
      expect(rows[other.index]?.status, 'revoked');
      expect(rows[other.index]?.alias, 'x');
      expect(
        valueOf(
          await inventory.mergeDerivationArchive(
            parent: _parent,
            records: [_hex(0), _hex(1)],
          ),
        ).unchanged,
        2,
      );
    },
  );

  test('an incompatible archive is refused without any write', () async {
    final local = valueOf(
      await inventory.reserveHexDerivation(parent: _parent, length: 32),
    );
    final bad = <List<RecordedDerivation>>[
      [_hex(5), _hex(5)],
      [_hex(5), _hex(6, parent: Fingerprint('89abcdef'))],
      [
        _hex(5),
        RecordedDerivation(
          path: "39'/0'/12'/9'",
          parentFingerprint: _parent.hex,
          application: 'hex',
          status: 'active',
          alias: null,
        ),
      ],
      [
        _hex(5),
        RecordedDerivation(
          path: "128169'/32'/0'",
          parentFingerprint: _parent.hex,
          application: 'bip39',
          status: 'active',
          alias: null,
        ),
      ],
      [_hex(5, length: 8)],
      [_hex(5, length: 65)],
      [_hex(5, status: 'deleted')],
      [
        RecordedDerivation(
          path: "128169'/32'/2147483648'",
          parentFingerprint: _parent.hex,
          application: 'hex',
          status: 'active',
          alias: null,
        ),
      ],
      [
        RecordedDerivation(
          path: "128169'/32'/007'",
          parentFingerprint: _parent.hex,
          application: 'hex',
          status: 'active',
          alias: null,
        ),
      ],
      [
        RecordedDerivation(
          path: '128169/32/5',
          parentFingerprint: _parent.hex,
          application: 'hex',
          status: 'active',
          alias: null,
        ),
      ],
      [
        _hex(5),
        // Same path as the local child, recorded under another application.
        RecordedDerivation(
          path: local.path,
          parentFingerprint: _parent.hex,
          application: 'bip39',
          status: 'active',
          alias: null,
        ),
      ],
    ];
    for (final records in bad) {
      final result = await inventory.mergeDerivationArchive(
        parent: _parent,
        records: records,
      );
      expect(result, isA<Err>(), reason: records.map((r) => r.path).join(','));
      expect((await stored()).map((record) => record.path), [local.path]);
    }
  });

  test('a parent outside the active view is refused', () async {
    final result = await inventory.mergeDerivationArchive(
      parent: Fingerprint('89abcdef'),
      records: [_hex(0, parent: Fingerprint('89abcdef'))],
    );
    expect(result, isA<Err>());
    expect(await stored(), isEmpty);
  });

  test('mnemonic children validate language and length', () async {
    RecordedDerivation mnemonic(String path) => RecordedDerivation(
      path: path,
      parentFingerprint: _parent.hex,
      application: 'bip39',
      status: 'active',
      alias: null,
    );
    expect(
      await inventory.mergeDerivationArchive(
        parent: _parent,
        records: [mnemonic("39'/0'/12'/2'")],
      ),
      isA<Ok>(),
    );
    for (final path in ["39'/10'/12'/0'", "39'/0'/13'/0'", "39'/0'/12'"]) {
      expect(
        await inventory.mergeDerivationArchive(
          parent: _parent,
          records: [mnemonic(path)],
        ),
        isA<Err>(),
        reason: path,
      );
    }
  });
}
