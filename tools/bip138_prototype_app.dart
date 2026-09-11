import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_relay_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/fetch_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/publish_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/descriptor_backup_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/descriptor_backup_prototype_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../test/features/bullvault/support/bip138_prototype_fixture.dart';
import '../test/features/bullvault/support/descriptor_backup_identity_fixture.dart';

/// Separate runnable test harness. Does not initialize Bull, secrets or metadata.
void main() => runApp(prototypeApp());

Widget prototypeApp({
  bool recoveryOnly = const bool.fromEnvironment('BIP138_RECOVERY_ONLY'),
}) {
  final repository = DescriptorBackupRepositoryImpl(
    Bip138Codec(),
    const DescriptorBackupRelayDatasource(),
  );
  final fixture = recoveryOnly ? null : Bip138PrototypeFixture();
  return MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider(
      create: (_) => DescriptorBackupCubit(
        FetchDescriptorBackupUsecase(repository),
        fixture == null
            ? null
            : PublishDescriptorBackupUsecase(
                repository,
                descriptorPrototypeIdentity(fixture.publishingRoot),
              ),
      ),
      child: DescriptorBackupPrototypeScreen(
        demoXpubs:
            fixture?.signers.map((s) => s.accountKey.xpub).toList() ?? const [],
        demoDescriptor: fixture?.descriptor(),
      ),
    ),
  );
}
