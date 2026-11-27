import 'dart:async';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/domain/entities/drive_file_metadata.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/delete_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/export_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/list_drive_vaults_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/manage_backup_settings_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/pick_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/read_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:bull_recoverbull/src/presentation/vault_flow_cubit.dart';
import 'package:bull_recoverbull/src/presentation/vault_flow_presentation.dart';
import 'package:bull_recoverbull/src/ui/pages/vault_provider_selection_page.dart';
import 'package:bull_recoverbull/src/ui/pages/vault_selected_page.dart';
import 'package:bull_recoverbull/src/ui/recoverbull_flow_navigator.dart';
import 'package:bull_ui/testing.dart';
import 'package:file_system/file_system.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final flow in [
    RecoverBullFlow.testVault,
    RecoverBullFlow.recoverVault,
  ]) {
    for (final scenario in ['exit', 'exit_read', 'drive', 'cancel']) {
      testWidgets('$flow opening ($scenario)', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        final drive = _Drive(holdRead: scenario == 'exit_read');
        final files = _Files();
        final vaults = _Vaults();
        final wallets = _Wallets();
        final previous = EncryptedVault(
          id: '44' * 32,
          salt: '55' * 16,
          ciphertext: List.filled(64, 0),
          createdAt: DateTime.utc(2025),
        );
        final cubit = VaultFlowCubit(
          const ManageBackupSettingsUsecase(
            null,
            RecoverBullStorageFullFailure(),
          ),
          (
            pick: PickVaultUsecase(files),
            list: ListDriveVaultsUsecase(drive),
            select: ReadDriveVaultUsecase(drive),
            delete: DeleteDriveVaultUsecase(drive),
            export: ExportDriveVaultUsecase(files, drive),
          ),
          null,
          CompleteVaultUsecase(
            TestVaultUsecase(vaults, wallets),
            RestoreVaultUsecase(vaults, wallets),
            null,
            null,
          ),
          unavailable: const RecoverBullStorageFullFailure(),
          vault: previous,
        );
        addTearDown(cubit.close);
        final presentation = VaultFlowPresentation(
          cubit,
          const Ok(BitcoinNetwork.testnet),
          null,
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => TextButton(
                onPressed: () => context.push('/selection'),
                child: const Text('Open'),
              ),
            ),
            GoRoute(
              path: '/selection',
              builder: (_, _) => RecoverBullFlowHost(
                flow: flow,
                presentation: presentation,
                page: const VaultProviderSelectionPage(),
                copiedMessage: 'Copied',
                onTestVault: () {},
                onFinished: () {},
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: ThemeData(extensions: testBullExtensions),
            localizationsDelegates: RecoverBullFeature.localizationsDelegates,
            supportedLocales: RecoverBullLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (scenario == 'cancel') {
          await tester.tap(find.text('Custom location').first);
          await tester.pumpAndSettle();
          expect(files.picks, 1);
          expect(cubit.state.failure, isNull);
          expect(cubit.state.vault, same(previous));
          expect(find.byType(VaultSelectedPage), findsNothing);
          expect(find.text('Custom location'), findsOneWidget);
          return;
        }
        await tester.tap(find.text('Google Drive').first);
        await tester.pump();
        expect(drive.listStarted, isTrue);
        if (scenario == 'exit') {
          router.pop();
          await tester.pumpAndSettle();
        }
        drive.answer.complete(
          Ok([
            DriveFileMetadata(
              id: 'a',
              name: 'vault',
              createdTime: DateTime.utc(2026),
            ),
          ]),
        );
        await tester.pump();
        if (scenario == 'exit_read') {
          expect(drive.reads, 1);
          router.pop();
          await tester.pumpAndSettle();
          drive.readAnswer.complete(Ok(drive.vault));
        }
        await tester.pumpAndSettle();
        if (scenario == 'exit' || scenario == 'exit_read') {
          expect(drive.reads, scenario == 'exit' ? 0 : 1);
          expect(cubit.state.vault, same(previous));
          expect(find.text('Open'), findsOneWidget);
        } else {
          expect(drive.reads, 1);
          expect(drive.readId, 'a');
          expect(cubit.state.vault, same(drive.vault));
          expect(find.byType(VaultSelectedPage), findsOneWidget);
        }
      });
    }
  }
}

final class _Files extends Fake implements FileSystem {
  int picks = 0;
  @override
  Future<Result<PickedDocument?, FileSystemFailure>> pick({
    List<String> allowedExtensions = const [],
  }) async {
    picks++;
    return const Ok(null);
  }
}

final class _Vaults extends Fake implements VaultRepository {}

final class _Wallets extends Fake implements RecoverBullWalletPort {}

final class _Drive extends Fake implements GoogleDriveRepository {
  final bool holdRead;
  _Drive({this.holdRead = false});
  bool listStarted = false;
  int reads = 0;
  final readAnswer = Completer<Result<EncryptedVault, RecoverBullFailure>>();
  String? readId;
  final vault = EncryptedVault(
    id: '11' * 32,
    salt: '22' * 16,
    ciphertext: List.filled(64, 0),
    createdAt: DateTime.utc(2026),
  );
  final answer =
      Completer<Result<List<DriveFileMetadata>, RecoverBullFailure>>();
  @override
  Future<Result<Null, RecoverBullFailure>> connect() async => const Ok(null);
  @override
  Future<Result<List<DriveFileMetadata>, RecoverBullFailure>>
  fetchAllMetadata() {
    listStarted = true;
    return answer.future;
  }

  @override
  Future<Result<EncryptedVault, RecoverBullFailure>> fetchVault(
    DriveFileMetadata file,
  ) async {
    reads++;
    readId = file.id;
    return holdRead ? readAnswer.future : Ok(vault);
  }
}
