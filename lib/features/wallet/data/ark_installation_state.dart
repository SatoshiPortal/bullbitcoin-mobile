import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Positive evidence captured before either Ark store can be initialized.
/// Missing files after a failed inventory never turn that failure into absence.
final class ArkInstallationState {
  final Directory _documents;
  final String _fundingPath;
  final SharedPreferencesAsync? _preferences;
  final bool wasNeverProvisioned;

  ArkInstallationState._(
    this._documents,
    this._fundingPath,
    this._preferences,
    this.wasNeverProvisioned,
  );

  static Future<ArkInstallationState> inspect({
    required Directory documents,
    required String fundingPath,
  }) async {
    if (SharedPreferencesAsyncPlatform.instance == null) {
      return ArkInstallationState._(documents, fundingPath, null, false);
    }
    final preferences = SharedPreferencesAsync();
    final absent = await _hasNoState(documents, fundingPath, preferences);
    return ArkInstallationState._(documents, fundingPath, preferences, absent);
  }

  Future<bool> remainsUnprovisioned() async {
    final preferences = _preferences;
    return wasNeverProvisioned &&
        preferences != null &&
        await _hasNoState(_documents, _fundingPath, preferences);
  }

  static Future<bool> _hasNoState(
    Directory documents,
    String fundingPath,
    SharedPreferencesAsync preferences,
  ) async {
    try {
      // List, rather than exists(): unreadable directories, broken links and
      // unexpected entry types must not certify the absence of custody state.
      for (final directory in {documents.path, p.dirname(fundingPath)}) {
        await for (final entry in Directory(
          directory,
        ).list(followLinks: false)) {
          final name = p.basename(entry.path);
          if ((directory == documents.path && name == 'ark') ||
              (directory == p.dirname(fundingPath) &&
                  name.startsWith(p.basename(fundingPath)))) {
            return false;
          }
        }
      }
      return !(await preferences.getKeys()).any(
        (key) => key.startsWith('ark.'),
      );
    } on Exception {
      return false;
    }
  }
}
