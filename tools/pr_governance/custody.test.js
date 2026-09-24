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

test('a new importer of flutter_secure_storage is flagged, the package and the app store are not', () => {
  const line = "+import 'package:flutter_secure_storage/flutter_secure_storage.dart';";
  assert.deepEqual(rules(reviewFiles([file('lib/features/swap/data/store.dart', [line])])), ['fss-import']);
  assert.deepEqual(rules(reviewFiles([file('packages/bull_tor/lib/x.dart', [line])])), ['fss-import']);
  assert.deepEqual(rules(reviewFiles([file('packages/secrets/lib/src/data/fss_datasource.dart', [line])])), []);
  assert.deepEqual(rules(reviewFiles([file('lib/core/storage/storage_locator.dart', [line])])), []);
});

test('a federated or platform-interface import of the plugin is flagged', () => {
  const result = reviewFiles([file('lib/a.dart', ["+import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';"])]);
  assert.deepEqual(rules(result), ['fss-import']);
});

test('an import of package:secrets internals is flagged outside the package', () => {
  const line = "+import 'package:secrets/src/data/secret_repository.dart';";
  assert.deepEqual(rules(reviewFiles([file('lib/core/wallet/x.dart', [line])])), ['secrets-src-import']);
  assert.deepEqual(rules(reviewFiles([file('packages/secrets/test/x_test.dart', [line])])), []);
});

test('a keystore dependency in another pubspec is flagged', () => {
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
