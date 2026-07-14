import 'dart:convert';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/data/models/backup_health_reminder_model.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_health_reminder_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesBackupHealthReminderRepository
    implements BackupHealthReminderRepository {
  static const _keyPrefix = 'backup_health_reminder_v1_';
  static const _version = 1;

  @override
  Future<Result<BackupHealthReminderRecord, BackupSettingsFailure>> fetch(
    String masterFingerprint,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString('$_keyPrefix$masterFingerprint');
      if (encoded == null) {
        return Ok(
          BackupHealthReminderRecord(masterFingerprint: masterFingerprint),
        );
      }

      try {
        final decoded = jsonDecode(encoded);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid reminder state');
        }
        final model = BackupHealthReminderModel.fromJson(decoded);
        if (model.version != _version) {
          return Ok(
            BackupHealthReminderRecord(masterFingerprint: masterFingerprint),
          );
        }

        return Ok(model.toEntity(masterFingerprint: masterFingerprint));
      } on FormatException catch (e, st) {
        log.warning(
          'Ignoring invalid backup health reminder state',
          error: e,
          trace: st,
        );
        return Ok(
          BackupHealthReminderRecord(masterFingerprint: masterFingerprint),
        );
      }
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to load backup health reminder state',
        error: e,
        trace: st,
      );
      return Err(BackupSettingsPersistenceFailure(e.toString()));
    }
  }

  @override
  Future<Result<void, BackupSettingsFailure>> save(
    BackupHealthReminderRecord record,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final model = BackupHealthReminderModel.fromEntity(
        record,
        version: _version,
      );
      final saved = await preferences.setString(
        '$_keyPrefix${record.masterFingerprint}',
        jsonEncode(model.toJson()),
      );
      if (!saved) {
        return const Err(BackupSettingsPersistenceFailure());
      }
      return const Ok(null);
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to save backup health reminder state',
        error: e,
        trace: st,
      );
      return Err(BackupSettingsPersistenceFailure(e.toString()));
    }
  }
}
