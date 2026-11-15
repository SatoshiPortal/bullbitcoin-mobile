import 'dart:async';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/domain/repositories/attempt_monitoring_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/backup_metadata_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_session_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_file_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_and_store_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/delete_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/export_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/list_drive_vaults_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/manage_backup_settings_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/manage_vault_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/open_key_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/pick_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/read_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:bull_recoverbull/src/presentation/vault_flow_cubit.dart';
import 'package:bull_recoverbull/src/presentation/vault_flow_presentation.dart';
import 'package:bull_recoverbull/src/ui/pages/connecting_page.dart';
import 'package:bull_recoverbull/src/ui/recoverbull_flow_navigator.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _filtered = 'Connection appears filtered';
const _censored =
    'Tor could not reach the network. This often means the connection is being filtered.';

void main() {
  late StreamController<TorConnectionState> tor;
  late _Sessions sessions;
  late VaultFlowPresentation presentation;
  late int torSettingsOpened;

  // Built inside each test: a cubit created in setUp would deliver its
  // states outside the widget test's fake async zone.
  void build() {
    tor = StreamController<TorConnectionState>.broadcast(sync: true);
    sessions = _Sessions();
    torSettingsOpened = 0;
    final metadata = _Metadata();
    final monitoring = _Monitoring();
    final complete = CompleteVaultUsecase(
      TestVaultUsecase(_Vaults(), _Wallets()),
      RestoreVaultUsecase(_Vaults(), _Wallets()),
      null,
      null,
    );
    final fetch = FetchVaultKeyUsecase(monitoring);
    presentation = VaultFlowPresentation(
      VaultFlowCubit(
        const ManageBackupSettingsUsecase(
          null,
          RecoverBullStorageFullFailure(),
        ),
        (
          pick: PickVaultUsecase(_Files()),
          list: ListDriveVaultsUsecase(_Drive()),
          select: ReadDriveVaultUsecase(_Drive()),
          delete: DeleteDriveVaultUsecase(_Drive()),
          export: ExportDriveVaultUsecase(_Files(), _Drive()),
        ),
        ManageVaultSessionUsecase(
          metadata,
          OpenKeyServerUsecase(metadata, sessions),
          fetch,
          CreateAndStoreVaultUsecase(
            CreateVaultUsecase(_Vaults(), _Wallets()),
            SaveVaultUsecase(_Files(), _Drive()),
            metadata,
            monitoring,
            fetch,
          ),
          complete,
        ),
        complete,
        unavailable: const RecoverBullStorageFullFailure(),
        tor: tor.stream,
      ),
      const Ok(BitcoinNetwork.testnet),
      null,
    );
  }

  Future<void> pumpPage(WidgetTester tester) async {
    build();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: RecoverBullFeature.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: RecoverBullFlowHost(
          flow: RecoverBullFlow.secureVault,
          presentation: presentation,
          page: const ConnectingPage(),
          copiedMessage: 'Copied',
          onTestVault: () {},
          onFinished: () {},
          onOpenTorSettings: () => torSettingsOpened++,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    if (!sessions.pending.isCompleted) {
      sessions.pending.complete(
        const Err(KeyServerFailure(KeyServerFailureKind.unavailable)),
      );
    }
    await tester.pump();
  }

  testWidgets('a network blocking Tor is announced as filtering, not offline', (
    tester,
  ) async {
    await pumpPage(tester);
    tor.add(
      const TorConnecting(
        source: TorSource.embedded,
        transport: TorTransport.direct,
        diagnostic: TorDiagnostic.cantReachTor,
      ),
    );
    await tester.pump(const Duration(seconds: 6));

    expect(find.text(_filtered), findsOneWidget);
    expect(
      find.text('There seems to be no internet connection.'),
      findsNothing,
    );
    expect(find.widgetWithText(BullButton, 'Retry'), findsNothing);
    await leave(tester);
  });

  testWidgets('the switch to Snowflake is announced and given time', (
    tester,
  ) async {
    await pumpPage(tester);
    tor
      ..add(
        const TorConnecting(
          source: TorSource.embedded,
          transport: TorTransport.direct,
          diagnostic: TorDiagnostic.cantReachTor,
        ),
      )
      ..add(
        const TorConnecting(
          source: TorSource.embedded,
          transport: TorTransport.snowflake,
          circumvention: true,
        ),
      );
    await tester.pump();

    expect(find.text('Active transport: Snowflake'), findsOneWidget);
    expect(find.text(_filtered), findsOneWidget);

    // Snowflake reports transient blockages while it bootstraps.
    tor.add(
      const TorConnecting(
        source: TorSource.embedded,
        transport: TorTransport.snowflake,
        diagnostic: TorDiagnostic.cantBootstrap,
        circumvention: true,
      ),
    );
    await tester.pump(const Duration(seconds: 6));

    expect(find.widgetWithText(BullButton, 'Retry'), findsNothing);
    expect(find.text('Active transport: Snowflake'), findsOneWidget);
    await leave(tester);
  });

  testWidgets(
    'a failure after filtering explains it, offers Tor settings and restarts Tor',
    (tester) async {
      await pumpPage(tester);
      tor.add(
        const TorConnecting(
          source: TorSource.embedded,
          transport: TorTransport.snowflake,
          circumvention: true,
        ),
      );
      await tester.pump();
      tor.add(
        const TorUnavailable(
          source: TorSource.embedded,
          failure: TorBootstrapFailure('stalled', TorDiagnostic.cantBootstrap),
        ),
      );
      sessions.pending.complete(
        const Err(KeyServerFailure(KeyServerFailureKind.unavailable)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(_censored), findsOneWidget);
      await tester.tap(find.widgetWithText(BullButton, 'Tor Settings'));
      expect(torSettingsOpened, 1);

      sessions.pending = Completer();
      await tester.tap(find.widgetWithText(BullButton, 'Retry'));
      await tester.pump();
      expect(sessions.restarts, [false, true]);
      await leave(tester);
    },
  );

  test('a ready route survives a directory refresh without blockage', () async {
    build();
    final cubit = presentation.cubit;
    final route = TorRoute(
      source: TorSource.embedded,
      endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 9150),
      evidence: TorReadinessEvidence.embeddedBootstrap,
      transport: TorTransport.direct,
    );
    tor.add(TorReady(route));
    tor.add(
      const TorConnecting(
        source: TorSource.embedded,
        transport: TorTransport.direct,
      ),
    );
    expect(cubit.state.tor, isA<TorReady>());

    tor.add(
      const TorConnecting(
        source: TorSource.embedded,
        transport: TorTransport.direct,
        diagnostic: TorDiagnostic.cantReachTor,
      ),
    );
    expect(cubit.state.tor, isA<TorConnecting>());
    await presentation.close();
    await tor.close();
  });
}

final class _Sessions implements KeyServerSessionRepository {
  Completer<Result<KeyServerRepository, RecoverBullFailure>> pending =
      Completer();
  final List<bool> restarts = [];

  @override
  Future<Result<KeyServerRepository, RecoverBullFailure>> open(
    Uri server, {
    bool restartEmbedded = false,
  }) {
    restarts.add(restartEmbedded);
    return pending.future;
  }
}

final class _Metadata extends Fake implements BackupMetadataRepository {
  @override
  Future<Result<BackupSettings, RecoverBullFailure>> settings() async => Ok(
    BackupSettings(
      server: Uri.parse(
        'http://5m7enm5y77tdgmaf3d5xuwa5c7fjma7v5ljtwxu4q5jtq6b5utspmpyd.onion',
      ),
      permissionGranted: true,
      monitoringEnabled: false,
      generation: 1,
    ),
  );
}

final class _Monitoring extends Fake implements AttemptMonitoringRepository {}

final class _Files extends Fake implements VaultFileRepository {}

final class _Drive extends Fake implements GoogleDriveRepository {}

final class _Vaults extends Fake implements VaultRepository {}

final class _Wallets extends Fake implements RecoverBullWalletPort {}
