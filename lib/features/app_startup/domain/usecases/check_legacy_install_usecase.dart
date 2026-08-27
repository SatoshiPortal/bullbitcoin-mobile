import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/app_startup/domain/legacy_seed.dart';

class CheckLegacyInstallUsecase {
  final KeyValueStorageDatasource<String> _secureStorage;
  final bool _isAndroid;

  CheckLegacyInstallUsecase({
    required this._secureStorage,
    required this._isAndroid,
  });

  /// Version marker written by pre-v5 (2023–2024 "BULL") builds.
  static const legacyVersionKey = 'version';
  static const _legacyPrefixes = ['0.1', '0.2', '0.3', '0.4'];

  /// True when this install carries data from a pre-v5 build. Those installs
  /// are no longer migrated — the startup flow gates them behind a backup
  /// screen instead.
  Future<bool> execute() async {
    // Android is the only platform that ever shipped a pre-v5 build, so
    // other platforms can't carry the marker — and reading the keychain
    // pre-first-unlock throws -25308 on iOS pre-warm launches.
    if (!_isAndroid) return false;

    final entries = await _secureStorage.getAll();

    final version = entries[legacyVersionKey];
    if (version != null && _legacyPrefixes.any(version.startsWith)) return true;

    // The marker is not the only signal, on purpose: seed material under the
    // legacy key shape is what actually matters, and relying on the marker
    // alone made a real 0.4.3 → 6.13 upgrade fall through to onboarding on a
    // device where the marker could not be read. Missing the gate is the
    // dangerous direction — the user would onboard, get a default wallet, and
    // the gate would then stay suppressed forever with the legacy seeds
    // unreachable.
    //
    // No false positive for an already-migrated user: the gate is only
    // consulted when no default wallet exists (see AppStartupBloc), and
    // current seeds are stored under a `seed_<fingerprint>` key, which cannot
    // parse as legacy (the key must equal the fingerprint).
    return entries.entries.any(
      (e) => LegacySeed.tryFromSecureStorageEntry(e.key, e.value) != null,
    );
  }
}
