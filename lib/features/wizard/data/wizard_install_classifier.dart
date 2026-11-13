import 'dart:convert';
import 'dart:io';

import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/wizard/domain/wizard_install_failure.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_install_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Classifies before initialization can create application storage.
class WizardInstallClassifier implements WizardInstallRepository {
  WizardInstallClassifier({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  static const _freshKey = 'wizard_fresh_install_in_progress';

  @override
  Future<Result<bool, WizardInstallFailure>> shouldRunWizard() async {
    try {
      return Ok(await _classify());
    } on Exception catch (error) {
      return Err(WizardInstallStorageFailure(error.runtimeType.toString()));
    }
  }

  Future<bool> _classify() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('wizard_completed_version') != null) return false;
    if (prefs.getBool(_freshKey) == true) {
      // savePending precedes markComplete; recover the committed choices if
      // the process stopped between those two writes.
      final payload = prefs.getString('wizard_pending_payload');
      if (payload != null) {
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
          throw const FormatException('Invalid wizard choices');
        }
        if (decoded['exchangeAccess'] is bool &&
            decoded['reportingConsent'] is bool) {
          if (!await prefs.setInt('wizard_completed_version', 1)) {
            throw const FileSystemException(
              'Unable to record wizard completion',
            );
          }
          return false;
        }
      }
      return true;
    }
    if (prefs.containsKey('last_seen_app_version') ||
        prefs.containsKey('wizard_pending_version')) {
      return false;
    }
    final directory = await _documentsDirectory();
    final database = File(p.join(directory.path, 'bullbitcoin_sqlite.sqlite'));
    if (await database.exists()) return false;
    if (!await prefs.setBool(_freshKey, true)) {
      throw const FileSystemException(
        'Unable to record wizard installation state',
      );
    }
    return true;
  }
}
