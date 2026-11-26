import 'dart:async';
import 'dart:io';

import 'package:backup_storage/backup_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:labels/labels.dart' show Labels;
import 'package:primitives/primitives.dart';
import 'package:secrets/metadata_backup.dart' show MetadataBackupInventory;
import 'package:secrets/secrets.dart' show Secrets;
import 'package:secrets/storage.dart' show SecretsInventory;

import '../generated/l10n/backup_metadata_localizations.dart';
import 'backup_metadata_locator.dart';
import 'data/backup_metadata_store.dart';
import 'data/bip138_backup_metadata_codec.dart';
import 'data/metadata_backup_inventory.dart' as data;
import 'data/metadata_backup_labels.dart';
import 'data/metadata_backup_secrets.dart';
import 'domain/usecases/run_backup_usecase.dart';
import 'presentation/backup_metadata_restore_cubit.dart';
import 'presentation/backup_metadata_settings_cubit.dart';
import 'ui/backup_metadata_flow.dart';

/// Runs a backup in the foreground when the user has turned the feature on.
///
/// A labels change is debounced; a resume runs at once. Until the user has
/// chosen a destination, a run touches nothing outside the app.
final class BackupMetadataTrigger {
  final RunBackupUsecase _run;
  final Stream<void> _changes;
  final Duration _debounce;
  StreamSubscription<void>? _subscription;
  Timer? _timer;
  bool _running = false;

  BackupMetadataTrigger({
    required this._run,
    required this._changes,
    this._debounce = const Duration(seconds: 5),
  });

  void start() {
    _subscription ??= _changes.listen((_) {
      _timer?.cancel();
      _timer = Timer(_debounce, onResumed);
    });
  }

  /// Also the entry point for a resume; safe to call at any time.
  Future<void> onResumed() async {
    if (_running) return;
    _running = true;
    try {
      await _run.execute();
    } finally {
      _running = false;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }
}

/// The data backup feature: composition, page and foreground trigger.
final class BackupMetadataFeature {
  final GetIt _locator;
  final List<BackupDestination> _destinations;
  final BackupMetadataTrigger trigger;

  BackupMetadataFeature._(this._locator, this._destinations, this.trigger);

  /// Composes the member over its owners. Nothing is read, written or
  /// scheduled until the user turns the feature on.
  static BackupMetadataFeature open({
    required GetIt locator,
    required SecretsInventory inventory,
    required Secrets secrets,
    required Labels labels,
    required File journal,
    required BackupMetadataKey journalKey,
    List<BackupStorage>? storages,
    String? defaultBitcoinWalletLabel,
    String? unnamedWalletLabel,
    required Future<bool> Function() hasSilentPaymentsWallet,
    required Future<bool> Function(Fingerprint, BitcoinNetwork) backupVerified,
  }) {
    final all = storages ?? [GoogleDriveBackupStorage()];
    final english = lookupBackupMetadataLocalizations(const Locale('en'));
    final store = BackupMetadataStore(path: journal.path, key: journalKey);
    final secretsPort = MetadataBackupSecrets(inventory);
    final inventoryPort = data.MetadataBackupInventory(
      wallets: () => inventory.metadataBackupWallets(secrets),
      store: store,
      secrets: secretsPort,
      hasSilentPaymentsWallet: hasSilentPaymentsWallet,
      // Group names are stored by the journal's owner, outside any widget
      // tree: until they carry a key instead of a string, the English catalog.
      defaultBitcoinWalletLabel:
          defaultBitcoinWalletLabel ?? english.defaultBitcoinWallet,
      unnamedWalletLabel: unnamedWalletLabel ?? english.unnamedWallet,
      backupVerified: backupVerified,
    );
    final labelsPort = MetadataBackupLabels(
      inventory: inventoryPort,
      labels: labels,
    );
    BackupMetadataLocator.setup(
      locator: locator,
      store: store,
      inventory: inventoryPort,
      labels: labelsPort,
      secrets: secretsPort,
      codec: const Bip138BackupMetadataCodec(),
      storages: all,
    );
    return BackupMetadataFeature._(
      locator,
      [for (final storage in all) storage.destination],
      BackupMetadataTrigger(
        run: locator<RunBackupUsecase>(),
        changes: labelsPort.changes,
      ),
    );
  }

  /// The page of the data backup journey, to mount in the host router.
  Widget page({required VoidCallback onClose}) => _BackupMetadataPage(
    settings: () => _locator<BackupMetadataSettingsCubit>(),
    restore: () => _locator<BackupMetadataRestoreCubit>(),
    destinations: _destinations,
    onClose: onClose,
  );
}

class _BackupMetadataPage extends StatefulWidget {
  final BackupMetadataSettingsCubit Function() settings;
  final BackupMetadataRestoreCubit Function() restore;
  final List<BackupDestination> destinations;
  final VoidCallback onClose;

  const _BackupMetadataPage({
    required this.settings,
    required this.restore,
    required this.destinations,
    required this.onClose,
  });

  @override
  State<_BackupMetadataPage> createState() => _BackupMetadataPageState();
}

class _BackupMetadataPageState extends State<_BackupMetadataPage> {
  late final BackupMetadataSettingsCubit _settings = widget.settings();
  late final BackupMetadataRestoreCubit _restore = widget.restore();

  @override
  void dispose() {
    unawaited(_settings.close());
    unawaited(_restore.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BackupMetadataFlow(
    settings: _settings,
    restore: _restore,
    destinations: widget.destinations,
    onClose: widget.onClose,
  );
}
