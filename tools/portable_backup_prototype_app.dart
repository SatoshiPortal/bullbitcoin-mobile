import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:bb_mobile/features/portable_backup/data/portable_backup_repository_impl.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/derive_backup_password_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/fetch_portable_vault_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/open_portable_backup_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/prepare_portable_backups_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/prepare_and_publish_portable_vault_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/publish_portable_vault_usecase.dart';
import 'package:bb_mobile/features/portable_backup/presentation/portable_backup_cubit.dart';
import 'package:bb_mobile/features/portable_backup/ui/portable_backup_prototype_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../test/features/bullvault/support/bip138_prototype_fixture.dart';
import '../test/features/wallet_backup/support/canonical_backup_snapshot.dart';

void main() => runApp(portableBackupPrototypeApp());

/// Standalone harness. No Bull initialization, secure storage or wallet imports.
Widget portableBackupPrototypeApp({
  bool recoveryOnly = !const bool.fromEnvironment('PORTABLE_BACKUP_DEMO'),
}) {
  final repository = PortableBackupRepositoryImpl(
    const RecoverBullEncryption(),
    const NostrRelayDatasource(),
  );
  final fixture = recoveryOnly ? null : Bip138PrototypeFixture();
  return MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider(
      create: (_) => PortableBackupCubit(
        PrepareAndPublishPortableVaultUsecase(
          PreparePortableBackupsUsecase(repository),
          PublishPortableVaultUsecase(repository),
        ),
        FetchPortableVaultUsecase(repository),
        OpenPortableBackupUsecase(repository),
      ),
      child: PortableBackupPrototypeScreen(
        demoDescriptor: fixture?.descriptor(),
        demoMetadataJson: fixture == null
            ? null
            : canonicalCodec().encode(canonicalFullSnapshot()),
        deriveDemoWords: fixture == null
            ? null
            : () => DeriveBackupPasswordUsecase(
                repository,
              ).execute(fixture.publishingRoot),
      ),
    ),
  );
}
