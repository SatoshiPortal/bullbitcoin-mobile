import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/storage.dart'
    show
        RegisteredWallet,
        SecretsInventory,
        SessionAuthority,
        SessionToken,
        multiViewSupported;
import 'package:secrets/src/data/inventory_store.dart';
import 'package:secrets/testing.dart';

/// A fresh admitted inventory file for the view tests. [close] releases it.
final class ViewFixture {
  final Directory directory;
  final File file;
  final RuntimeAdmission admission;

  ViewFixture._(this.directory, this.file, this.admission);

  static Future<ViewFixture> create() async {
    final directory = await Directory.systemTemp.createTemp('views-');
    FakeSecureStoragePlatform().install();
    final file = File('${directory.path}/secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final participant = SecretsImport(file: file);
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final result = await participant.prepare(exclusive, OwnerOrigin.fresh);
      final owner = (result as Ok<PreparedOwner, LegacyImportFailure>).value;
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await exclusive.close();
    }
    final admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    return ViewFixture._(directory, file, admission);
  }

  /// Runs raw SQL on the file the way a build that supports more views would
  /// have left it.
  Future<void> sql(List<String> statements) async {
    final opened = await InventoryStore.open(file, admission, existing: true);
    final store = (opened as Ok<InventoryStore, Failure>).value;
    try {
      for (final statement in statements) {
        await store.database.customStatement(statement);
      }
    } finally {
      await store.close();
    }
  }

  /// Raw SQL on the file while [inventory] holds it open, for the tests that
  /// build a layout no operation produces yet.
  Future<void> sqlWhileOpen(
    SecretsInventory inventory,
    List<String> statements,
  ) => sql(statements);

  /// The remembered view, read straight from the file.
  Future<String?> lastView(SecretsInventory inventory) async {
    final opened = await InventoryStore.open(file, admission, existing: true);
    final store = (opened as Ok<InventoryStore, Failure>).value;
    try {
      final row = await store.database
          .customSelect('SELECT last_view_id AS v FROM access_state')
          .getSingle();
      return row.read<String?>('v');
    } finally {
      await store.close();
    }
  }

  /// Whether the file still has the shape written before `last_view_id`,
  /// read without adapting it.
  Future<bool> hasLastViewColumn() async {
    final opened = await InventoryStore.open(file, admission, existing: true);
    final store = (opened as Ok<InventoryStore, Failure>).value;
    try {
      final rows = await store.database
          .customSelect(
            "SELECT 1 FROM pragma_table_info('access_state') "
            "WHERE name = 'last_view_id'",
          )
          .get();
      return rows.isNotEmpty;
    } finally {
      await store.close();
    }
  }

  Future<void> close() async {
    try {
      await admission.close();
    } on Object {
      // Already closed by the test.
    }
    await directory.delete(recursive: true);
  }
}

/// A wallet row named [name]; its id carries the origin the decoder needs.
/// A `local` wallet belongs to its own secret [fingerprint]; any
/// other signer is a public wallet owned by the view alone.
RegisteredWallet viewWallet(
  String name, {
  String fingerprint = '01234567',
  String signer = 'none',
  String network = 'bitcoinTestnet',
}) => RegisteredWallet(
  id: '$name[$fingerprint/84h/1h/0h]',
  secretFingerprint: signer == 'local' ? fingerprint : null,
  masterFingerprint: signer == 'none' ? '' : fingerprint,
  signer: signer,
  network: network,
  xpub: 'public-key-marker',
  externalDescriptor: "wpkh([$fingerprint/84'/1'/7']public-key-marker/0/*)",
  internalDescriptor: "wpkh(public-key-marker/1/*)",
  label: 'label-$name',
  birthday: '2026-11-21T00:00:00Z',
  isDefault: false,
);

T ok<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}

/// Suites that need a build supporting more than one view. The gate is a
/// compile-time constant, so they run in their own invocation, with
/// `--dart-define=BULL_MULTI_VIEW=true` (`make secrets-multiview-test`), and
/// are skipped in the ordinary one. Nothing at run time can open the gate.
void multiViewSuite(void Function() body) => group(
  'with the multiple-view build',
  body,
  skip: multiViewSupported
      ? false
      : 'run with --dart-define=BULL_MULTI_VIEW=true',
);

/// The value, or a failed expectation: the tests' replacement for `!`.
T present<T extends Object>(T? value) {
  if (value case final found?) return found;
  fail('expected a value, found null');
}

/// Replaces a grant synchronously without advancing the inventory's own epoch.
SessionToken replaceGrant(SessionAuthority authority, String view) =>
    authority.grant(view);
