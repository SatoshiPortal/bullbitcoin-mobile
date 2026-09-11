import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_electrum_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_wallet_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_descriptor_backup_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/fetch_bitcoin_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bitcoin_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bitcoin_backup_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bitcoin_backup_prototype_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'bip138_prototype_app.dart' as nostr;

/// Recovery-only composition root: no seed, fixture, metadata or Bull.init.
void main() => runApp(
  distributedPrototypeApp(
    network: BitcoinBackupNetwork.values.byName(
      const String.fromEnvironment(
        'DISTRIBUTED_NETWORK',
        defaultValue: 'regtest',
      ),
    ),
  ),
);

Widget distributedPrototypeApp({
  String endpoint = const String.fromEnvironment(
    'BACKUP_ELECTRUM',
    defaultValue: 'tcp://127.0.0.1:51401',
  ),
  BitcoinBackupNetwork network = BitcoinBackupNetwork.regtest,
}) {
  final repository = BitcoinDescriptorBackupRepositoryImpl(
    const BitcoinBackupElectrumDatasource(ElectrumSocketConnector()),
    BitcoinBackupWalletDatasource(
      () async =>
          '${(await getApplicationSupportDirectory()).path}/distributed-backup-prototype',
    ),
  );
  return MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: {'/nostr': (_) => nostr.prototypeApp(recoveryOnly: true)},
    home: Builder(
      builder: (context) => BlocProvider(
        create: (_) => BitcoinBackupCubit(
          FetchBitcoinBackupUsecase(repository),
          RestoreBitcoinBackupUsecase(repository),
        ),
        child: BitcoinBackupPrototypeScreen(
          initialEndpoint: endpoint,
          initialNetwork: network,
          onOpenNostr: () => Navigator.of(context).pushNamed('/nostr'),
        ),
      ),
    ),
  );
}
