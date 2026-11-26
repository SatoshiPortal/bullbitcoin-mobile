'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { MARKER, reviewFiles, reviewTree, commentBody } = require('./custody');

const patch = (start, lines) => `@@ -${start},1 +${start},${lines.length} @@\n${lines.join('\n')}`;
const file = (filename, lines, extra = {}) => ({ filename, status: 'modified', patch: patch(10, lines), ...extra });
const rules = (result) => result.findings.map((f) => f.rule);

test('an ignore of the seal is flagged anywhere, with its line', () => {
  const result = reviewFiles([file('lib/features/x/y.dart', [' context', '+  // ignore: invalid_use_of_internal_member', '+  secret.revealMnemonic();'])]);
  assert.deepEqual(rules(result), ['seal-ignore']);
  assert.equal(result.findings[0].line, 11);
});

test('ignore_for_file and a list of codes are flagged too', () => {
  const result = reviewFiles([file('test/a_test.dart', ['+// ignore_for_file: avoid_print, invalid_use_of_internal_member'])]);
  assert.deepEqual(rules(result), ['seal-ignore']);
});

test('the generated bridge of rust_bindings, onion and ark may silence the seal, hand-written code may not', () => {
  const line = '+// ignore_for_file: invalid_use_of_internal_member, unused_import';
  assert.deepEqual(rules(reviewFiles([file('packages/rust_bindings/lib/src/rust/frb_generated.dart', [line])])), []);
  assert.deepEqual(rules(reviewFiles([file('packages/onion/lib/src/rust/api/client.dart', [line])])), []);
  assert.deepEqual(rules(reviewFiles([file('packages/ark/lib/src/rust/frb_generated.dart', [line])])), []);
  assert.deepEqual(rules(reviewFiles([file('packages/rust_bindings/lib/boltz.dart', [line])])), ['seal-ignore']);
  assert.deepEqual(rules(reviewFiles([file('packages/ark/lib/ark.dart', [line])])), ['seal-ignore']);
  assert.deepEqual(rules(reviewFiles([file('packages/secrets/lib/src/rust/x.dart', [line])])), ['seal-ignore']);
  assert.deepEqual(rules(reviewFiles([file('lib/src/rust/frb_generated.dart', [line])])), ['seal-ignore']);
});

test('the bindings packages may not reach package:secrets, in Dart or in their pubspec', () => {
  const line = "+import 'package:secrets/secrets.dart';";
  assert.deepEqual(rules(reviewFiles([file('packages/rust_bindings/lib/src/rust/api/simple.dart', [line])])), ['bindings-secrets']);
  assert.deepEqual(rules(reviewFiles([file('packages/onion/lib/custom.dart', [line])])), ['bindings-secrets']);
  assert.deepEqual(rules(reviewFiles([file('packages/ark/lib/src/rust/api/wallet.dart', [line])])), ['bindings-secrets']);
  assert.deepEqual(rules(reviewFiles([file('packages/rust_bindings/pubspec.yaml', ['+  secrets:'])])), ['bindings-secrets-dependency']);
  assert.deepEqual(rules(reviewFiles([file('packages/ark/pubspec.yaml', ['+  secrets:'])])), ['bindings-secrets-dependency']);
  assert.deepEqual(rules(reviewFiles([file('packages/rust_bindings/lib/a.dart', ['+  f(secrets: x);'])])), []);
  assert.deepEqual(rules(reviewFiles([file('packages/sync/lib/x.dart', [line])])), []);
});

test('a new importer of flutter_secure_storage is flagged, only the secrets package is exempt', () => {
  const line = "+import 'package:flutter_secure_storage/flutter_secure_storage.dart';";
  assert.deepEqual(rules(reviewFiles([file('lib/features/swap/data/store.dart', [line])])), ['fss-import']);
  assert.deepEqual(rules(reviewFiles([file('packages/bull_tor/lib/x.dart', [line])])), ['fss-import']);
  assert.deepEqual(rules(reviewFiles([file('packages/secrets/lib/src/data/fss_datasource.dart', [line])])), []);
  assert.deepEqual(rules(reviewFiles([file('lib/core/storage/storage_locator.dart', [line])])), ['fss-import']);
});

test('a federated or platform-interface import of the plugin is flagged', () => {
  const result = reviewFiles([file('lib/a.dart', ["+import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';"])]);
  assert.deepEqual(rules(result), ['fss-import']);
});

test('an import split across lines, or conditional, is flagged on its URI', () => {
  const split = reviewTree([{ path: 'lib/a.dart', text: "import\n    'package:flutter_secure_storage/flutter_secure_storage.dart';\n" }]);
  assert.deepEqual(split.map((f) => [f.rule, f.line]), [['fss-import', 2]]);
  const conditional = reviewFiles([file('lib/b.dart', ["+    if (dart.library.io) 'package:secrets/src/data/secret_repository.dart';"])]);
  assert.deepEqual(rules(conditional), ['secrets-src-import']);
});

test('an import of package:secrets internals is flagged outside the package', () => {
  const line = "+import 'package:secrets/src/data/secret_repository.dart';";
  assert.deepEqual(rules(reviewFiles([file('lib/core/wallet/x.dart', [line])])), ['secrets-src-import']);
  assert.deepEqual(rules(reviewFiles([file('packages/secrets/test/x_test.dart', [line])])), []);
});

test('a keystore dependency in another pubspec is flagged', () => {
  assert.deepEqual(rules(reviewFiles([file('pubspec.yaml', ['+  flutter_secure_storage: ^10.3.3'])])), ['fss-dependency']);
  const result = reviewFiles([file('packages/bull_ui/pubspec.yaml', ['+  flutter_secure_storage: ^10.3.3'])]);
  assert.deepEqual(rules(result), ['fss-dependency']);
  assert.deepEqual(rules(reviewFiles([file('packages/secrets/pubspec.yaml', ['+  flutter_secure_storage: ^10.3.4'])])), []);
});

test('removed and context lines are not findings, and line numbers follow the new file', () => {
  const result = reviewFiles([file('lib/a.dart', ["-import 'package:flutter_secure_storage/flutter_secure_storage.dart';", " import 'package:flutter_secure_storage/x.dart';", "+import 'package:flutter_secure_storage/y.dart';"])]);
  assert.equal(result.findings.length, 1);
  assert.equal(result.findings[0].line, 11);
});

test('a removed file is ignored, a relevant file without a patch is reported uninspected', () => {
  assert.deepEqual(reviewFiles([{ filename: 'lib/a.dart', status: 'removed' }]), { findings: [], uninspected: [] });
  assert.deepEqual(reviewFiles([{ filename: 'lib/a.dart', status: 'modified' }]).uninspected, ['lib/a.dart']);
  assert.deepEqual(reviewFiles([{ filename: 'README.md', status: 'modified' }]).uninspected, []);
});

test('the tree scan finds the same rules with 1-based lines', () => {
  const findings = reviewTree([{ path: 'lib/a.dart', text: "void main() {}\n// ignore: invalid_use_of_internal_member\n" }]);
  assert.deepEqual(findings.map((f) => [f.rule, f.line]), [['seal-ignore', 2]]);
});

test('the comment asks why, lists each finding, and is marked for updates', () => {
  const body = commentBody(reviewFiles([file('lib/a.dart', ['+  // ignore: invalid_use_of_internal_member'])]));
  assert.ok(body.startsWith(MARKER));
  assert.match(body, /explain, in a reply, why/);
  assert.match(body, /`lib\/a.dart` \| 10 \|/);
});

test('no finding: no comment, unless one must be updated to say so', () => {
  assert.equal(commentBody({ findings: [], uninspected: [] }), null);
  assert.match(commentBody({ findings: [], uninspected: [] }, { hadComment: true }), /No change to the custody boundary remains/);
});

const unchangedRename = {
  filename: 'lib/core/exchange/data/http/bullbitcoin_api_dio_factory.dart',
  previous_filename: 'lib/core/exchange/data/datasources/http/bullbitcoin_api_dio_factory.dart',
  status: 'renamed',
  changes: 0,
  additions: 0,
  deletions: 0,
};

test('the unchanged Dio factory rename from PR #3028 needs no custody comment', () => {
  const result = reviewFiles([unchangedRename]);
  assert.deepEqual(result, { findings: [], uninspected: [] });
  assert.equal(commentBody(result), null);
});

test('an unchanged rename across a custody policy boundary stays uninspected', () => {
  for (const previous_filename of ['packages/secrets/lib/store.dart']) {
    const renamed = { ...unchangedRename, previous_filename };
    assert.deepEqual(reviewFiles([renamed]), { findings: [], uninspected: [renamed.filename] });
  }
});

test('missing rename evidence or nonzero changes cannot bypass inspection', () => {
  for (const extra of [
    { status: 'modified' }, { previous_filename: undefined }, { previous_filename: '' },
    { changes: undefined }, { additions: undefined }, { deletions: undefined },
    { changes: 1 }, { additions: 1 }, { deletions: 1 }, { changes: '0' },
  ]) {
    const renamed = { ...unchangedRename, ...extra };
    assert.deepEqual(reviewFiles([renamed]).uninspected, [renamed.filename]);
  }
});

test('a supplied rename patch is inspected even with unchanged counters', () => {
  const result = reviewFiles([{ ...unchangedRename, patch: patch(1, ["+import 'package:flutter_secure_storage/flutter_secure_storage.dart';"]) }]);
  assert.deepEqual(rules(result), ['fss-import']);
});

test('missing patches alone report incomplete inspection without claiming a custody change or large diff', () => {
  const body = commentBody(reviewFiles([{ filename: 'lib/a.dart', status: 'modified' }]));
  assert.match(body, /inspection is incomplete/);
  assert.match(body, /GitHub did not provide a patch/);
  assert.match(body, /`lib\/a.dart`/);
  assert.doesNotMatch(body, /touches the boundary|diff this large|why each change/);
});
