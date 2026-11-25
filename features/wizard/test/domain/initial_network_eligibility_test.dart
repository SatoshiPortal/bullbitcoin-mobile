import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizard/wizard.dart';

void main() {
  late Directory root;
  late Directory documents;
  late Directory support;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory('/tmp/opencode').createTemp('wizard-eligibility-');
    documents = await Directory('${root.path}/documents').create();
    support = await Directory('${root.path}/support').create();
  });

  tearDown(() async => root.delete(recursive: true));

  Future<bool> eligible() => WizardFeature.mayOfferInitialNetwork(
    documents: documents,
    support: support,
  );

  test('allows a new installation with no application storage', () async {
    expect(await eligible(), isTrue);
  });

  test('refuses a legacy database family', () async {
    await File('${documents.path}/bullbitcoin_sqlite.sqlite-wal').create();
    expect(await eligible(), isFalse);
  });

  test('refuses existing owner storage and coordination markers', () async {
    final databases = await Directory('${support.path}/databases').create();
    await File('${databases.path}/preferences.sqlite').create();
    expect(await eligible(), isFalse);
    await File('${databases.path}/preferences.sqlite').delete();
    final coordination = await Directory('${support.path}/storage-coordination')
        .create();
    await File('${coordination.path}/split-v1.json').create();
    expect(await eligible(), isFalse);
  });

  test('refuses an uninspectable storage directory link', () async {
    await Link('${support.path}/databases').create('${root.path}/missing');
    expect(await eligible(), isFalse);
  });

  test(
    'refuses a previously completed wizard and unreadable evidence',
    () async {
      SharedPreferences.setMockInitialValues({'wizard_completed_version': 1});
      expect(await eligible(), isFalse);
      SharedPreferences.setMockInitialValues({});
      await documents.delete();
      expect(await eligible(), isFalse);
    },
  );
}
