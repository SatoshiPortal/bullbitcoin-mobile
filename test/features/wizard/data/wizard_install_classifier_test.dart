import 'dart:io';

import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bb_mobile/features/wizard/data/wizard_install_classifier.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_install_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory directory;
  late WizardInstallClassifier classifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('wizard-classifier-');
    classifier = WizardInstallClassifier(
      documentsDirectory: () async => directory,
    );
  });

  tearDown(() async => directory.delete(recursive: true));

  test(
    'fresh install remains fresh after interruption even if database appears',
    () async {
      expect(
        await classifier.shouldRunWizard(),
        isA<Ok<bool, WizardInstallFailure>>().having(
          (r) => r.value,
          'value',
          isTrue,
        ),
      );
      await File('${directory.path}/bullbitcoin_sqlite.sqlite').create();
      expect(
        await classifier.shouldRunWizard(),
        isA<Ok<bool, WizardInstallFailure>>().having(
          (r) => r.value,
          'value',
          isTrue,
        ),
      );
    },
  );

  test('existing database without wizard marker does not replay', () async {
    await File('${directory.path}/bullbitcoin_sqlite.sqlite').create();
    expect(
      await classifier.shouldRunWizard(),
      isA<Ok<bool, WizardInstallFailure>>().having(
        (r) => r.value,
        'value',
        isFalse,
      ),
    );
  });

  test('completed wizard does not replay', () async {
    SharedPreferences.setMockInitialValues({'wizard_completed_version': 1});
    expect(
      await classifier.shouldRunWizard(),
      isA<Ok<bool, WizardInstallFailure>>().having(
        (r) => r.value,
        'value',
        isFalse,
      ),
    );
  });

  test('old application version marker does not replay', () async {
    SharedPreferences.setMockInitialValues({'last_seen_app_version': '1.0'});
    expect(
      await classifier.shouldRunWizard(),
      isA<Ok<bool, WizardInstallFailure>>().having(
        (r) => r.value,
        'value',
        isFalse,
      ),
    );
  });

  test('old pending choices do not replay', () async {
    SharedPreferences.setMockInitialValues({'wizard_pending_version': 1});
    expect(
      await classifier.shouldRunWizard(),
      isA<Ok<bool, WizardInstallFailure>>().having(
        (r) => r.value,
        'value',
        isFalse,
      ),
    );
  });
  test('storage failure is returned rather than classified as fresh', () async {
    final broken = WizardInstallClassifier(
      documentsDirectory: () async =>
          throw const FileSystemException('unavailable'),
    );
    expect(
      await broken.shouldRunWizard(),
      isA<Err<bool, WizardInstallFailure>>(),
    );
  });
  test('recovers completed choices saved before completion marker', () async {
    SharedPreferences.setMockInitialValues({
      'wizard_fresh_install_in_progress': true,
      'wizard_pending_payload':
          '{"version":1,"exchangeAccess":false,"reportingConsent":true}',
    });
    expect(
      await classifier.shouldRunWizard(),
      isA<Ok<bool, WizardInstallFailure>>().having(
        (r) => r.value,
        'value',
        false,
      ),
    );
    expect(
      (await SharedPreferences.getInstance()).getInt(
        'wizard_completed_version',
      ),
      1,
    );
  });
}
