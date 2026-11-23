import 'dart:io';

import 'package:ark/funding.dart';
import 'package:path/path.dart' as p;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show SeedReferencePort, SeedReferencesUnavailable;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Positive evidence captured before either Ark store can be initialized.
/// Missing files after a failed inventory never turn that failure into absence.
final class ArkInstallationState implements ArkInstallationEvidence {
  final Directory _documents;
  final String _fundingPath;
  final SharedPreferencesAsync? _preferences;
  final bool wasNeverProvisioned;
  bool _absenceLost = false;

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

  @override
  Future<bool> remainsUnprovisioned() async {
    final preferences = _preferences;
    if (!wasNeverProvisioned || _absenceLost || preferences == null) {
      return false;
    }
    final absent = await _hasNoState(_documents, _fundingPath, preferences);
    // Once observed, custody state or a failed inventory cannot be erased by
    // later file loss. Concurrent successful reads never rearm this evidence.
    if (!absent) _absenceLost = true;
    return absent && !_absenceLost;
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

/// Ark funding seed references while the funding authority is unavailable.
/// An opening failure remains an owner; only proven absence has none.
final class UnavailableArkFundingReferences implements SeedReferencePort {
  final ArkInstallationState _installation;

  const UnavailableArkFundingReferences(this._installation);

  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async =>
      await _installation.remainsUnprovisioned()
      ? const Ok({})
      : const Err(SeedReferencesUnavailable());
}
