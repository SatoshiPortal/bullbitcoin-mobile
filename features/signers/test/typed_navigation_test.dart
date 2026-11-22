import 'dart:async';

import 'package:bull_ui/bull_ui.dart'
    show BullSnackBar, bullUiLocalizationsDelegate;
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signers/routes.dart';
import 'package:signers/src/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:signers/src/bitbox/domain/errors/bitbox_failure.dart';
import 'package:signers/src/bitbox_flow/bitbox_action.dart';
import 'package:signers/src/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:signers/src/bitbox_flow/presentation/cubit/bitbox_operation_cubit.dart';
import 'package:signers/src/bitbox_flow/ui/screens/bitbox_action_screen.dart';
import 'package:signers/src/ledger/domain/entities/ledger_device_entity.dart';
import 'package:signers/src/ledger_flow/ledger_action.dart';
import 'package:signers/src/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:signers/src/ledger_flow/presentation/cubit/ledger_operation_cubit.dart';
import 'package:signers/src/ledger_flow/ui/screens/ledger_action_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:signers/signers.dart';

class _LedgerRepository extends Mock implements LedgerDeviceRepository {}

class _BitBoxRepository extends Mock implements BitBoxDeviceRepository {}

void main() {
  const account = SignerAccount(
    masterFingerprint: '12345678',
    derivationPath: "m/84'/1'/0'",
    xpub: 'public account fixture',
    scriptType: ScriptType.bip84,
    device: SignerDevice.ledgerNanoX,
    network: NetworkEnv.testnet,
  );
  for (final ledger in [true, false]) {
    for (final operation in [
      'import',
      'sign',
      'verify',
      'cancel',
      if (!ledger) 'cancel during readiness',
    ]) {
      testWidgets(
        '${ledger ? 'Ledger' : 'BitBox'} $operation keeps its typed request and result',
        (tester) async {
          Object? returned;
          var completed = false;
          final services = GetIt.asNewInstance();
          final feature = SignersFeature.mount(
            services: services,
            writeNfc: (_, _, _, _) async {},
          );
          addTearDown(services.reset);
          final ledgerRepository = _LedgerRepository();
          final bitBoxRepository = _BitBoxRepository();
          when(ledgerRepository.dispose)
              .thenAnswer((_) async => const Ok(null));
          when(bitBoxRepository.dispose)
              .thenAnswer((_) async => const Ok(null));
          await services.unregister<LedgerDeviceRepository>();
          await services.unregister<BitBoxDeviceRepository>();
          services.registerSingleton<LedgerDeviceRepository>(ledgerRepository);
          services.registerSingleton<BitBoxDeviceRepository>(bitBoxRepository);
          final requestedDevice = ledger
              ? SignerDevice.ledgerNanoX
              : SignerDevice.bitbox02;
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      switch (operation) {
                        case 'import':
                        case 'cancel':
                        case 'cancel during readiness':
                          final SignerAccount? result = ledger
                              ? await SignersNavigation.importLedger(
                                  context,
                                  network: NetworkEnv.testnet,
                                  requestedDeviceType: requestedDevice,
                                )
                              : await SignersNavigation.importBitBox(
                                  context,
                                  network: NetworkEnv.testnet,
                                  requestedDeviceType: requestedDevice,
                                );
                          returned = result;
                        case 'sign':
                          final String? result = ledger
                              ? await SignersNavigation.signLedger(
                                  context,
                                  network: NetworkEnv.testnet,
                                  requestedDeviceType: requestedDevice,
                                  psbt: 'unsigned',
                                  derivationPath: account.derivationPath,
                                  scriptType: ScriptType.bip84,
                                )
                              : await SignersNavigation.signBitBox(
                                  context,
                                  network: NetworkEnv.testnet,
                                  requestedDeviceType: requestedDevice,
                                  psbt: 'unsigned',
                                  derivationPath: account.derivationPath,
                                  scriptType: ScriptType.bip84,
                                );
                          returned = result;
                        case 'verify':
                          if (ledger) {
                            await SignersNavigation.verifyLedger(
                              context,
                              network: NetworkEnv.testnet,
                              requestedDeviceType: requestedDevice,
                              address: 'address',
                              derivationPath: account.derivationPath,
                              scriptType: ScriptType.bip84,
                            );
                          } else {
                            await SignersNavigation.verifyBitBox(
                              context,
                              network: NetworkEnv.testnet,
                              requestedDeviceType: requestedDevice,
                              address: 'address',
                              derivationPath: account.derivationPath,
                              scriptType: ScriptType.bip84,
                            );
                          }
                      }
                      completed = true;
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
              ...feature.routes,
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              theme: ThemeData(extensions: testBullExtensions),
              localizationsDelegates: const [
                bullUiLocalizationsDelegate,
                ...SignersLocalizations.localizationsDelegates,
              ],
              supportedLocales: SignersLocalizations.supportedLocales,
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final screen = ledger
              ? tester.widget<LedgerActionScreen>(
                  find.byType(LedgerActionScreen),
                )
              : tester.widget<BitBoxActionScreen>(
                  find.byType(BitBoxActionScreen),
                );
          final (
            network,
            psbt,
            address,
            path,
            script,
            device,
          ) = switch (screen) {
            LedgerActionScreen(:final parameters) => (
              parameters.network,
              parameters.psbt,
              parameters.address,
              parameters.derivationPath,
              parameters.scriptType,
              parameters.requestedDeviceType,
            ),
            BitBoxActionScreen(:final parameters) => (
              parameters.network,
              parameters.psbt,
              parameters.address,
              parameters.derivationPath,
              parameters.scriptType,
              parameters.requestedDeviceType,
            ),
            _ => throw StateError('Missing signer route request'),
          };
          expect(network, NetworkEnv.testnet);
          expect(psbt, operation == 'sign' ? 'unsigned' : null);
          expect(address, operation == 'verify' ? 'address' : null);
          final needsPath = operation == 'sign' || operation == 'verify';
          expect(path, needsPath ? account.derivationPath : null);
          expect(script, needsPath ? ScriptType.bip84 : null);
          expect(device, requestedDevice);
          if (screen case LedgerActionScreen(:final action)) {
            expect(action, switch (operation) {
              'sign' => const LedgerAction.signTransaction(),
              'verify' => const LedgerAction.verifyAddress(),
              _ => const LedgerAction.importWallet(),
            });
          }
          if (screen case BitBoxActionScreen(:final action)) {
            expect(action, switch (operation) {
              'sign' => const BitBoxAction.signTransaction(),
              'verify' => const BitBoxAction.verifyAddress(),
              _ => const BitBoxAction.importWallet(),
            });
          }
          final routeContext = tester.element(find.byType(Scaffold));
          final ledgerCubit = ledger
              ? routeContext.read<LedgerOperationCubit>()
              : null;
          final bitBoxCubit = ledger
              ? null
              : routeContext.read<BitBoxOperationCubit>();
          final result = switch (operation) {
            'import' => account,
            'sign' => 'signed',
            _ => null,
          };
          if (operation == 'cancel') {
            router.pop();
          } else if (ledgerCubit != null) {
            const device = LedgerDeviceEntity(
              id: 'ledger-fixture',
              name: 'Ledger fixture',
              connectionType: LedgerConnectionType.usb,
              deviceType: SignerDevice.ledgerNanoX,
            );
            when(
              () => ledgerRepository.scanDevices(deviceType: requestedDevice),
            ).thenAnswer((_) async => const Ok([device]));
            when(() => ledgerRepository.connectDevice(device))
                .thenAnswer((_) async => const Ok(null));
            await ledgerCubit.executeOperation(() async => Ok(result));
          } else if (bitBoxCubit != null) {
            const device = BitBoxDeviceEntity(
              deviceName: 'BitBox fixture',
              serialNumber: 'fixture',
              product: 'BitBox02',
              connectionType: BitBoxConnectionType.usb,
            );
            when(bitBoxRepository.scanDevices)
                .thenAnswer((_) async => const Ok([device]));
            when(() => bitBoxRepository.connectDevice(device))
                .thenAnswer((_) async => const Ok(null));
            if (operation == 'cancel during readiness') {
              final fingerprint = Completer<Result<String, BitBoxFailure>>();
              when(() => bitBoxRepository.getMasterFingerprint(device))
                  .thenAnswer((_) => fingerprint.future);
              when(() => bitBoxRepository.unlockDevice(device)).thenAnswer(
                (_) async => const Err(DeviceNotFoundBitBoxFailure()),
              );
              final loc = SignersLocalizations.of(routeContext);
              final import = find.text(loc.bitboxActionImportWalletButton);
              await tester.ensureVisible(import);
              await tester.tap(import);
              await tester.pump();
              verify(() => bitBoxRepository.getMasterFingerprint(device))
                  .called(1);
              router.pop();
              await tester.pumpAndSettle();
              expect(bitBoxCubit.isClosed, isTrue);

              fingerprint.complete(const Err(DeviceNotFoundBitBoxFailure()));
              await tester.pumpAndSettle();
              verifyNever(() => bitBoxRepository.unlockDevice(device));
            } else {
              await bitBoxCubit.executeOperation(() async => Ok(result));
            }
          }
          await tester.pumpAndSettle();
          expect((ledgerCubit ?? bitBoxCubit)?.isClosed, isTrue);
          if (ledger) {
            verify(ledgerRepository.dispose).called(1);
            verifyNever(bitBoxRepository.dispose);
          } else {
            verify(bitBoxRepository.dispose).called(1);
            verifyNever(ledgerRepository.dispose);
          }
          expect(completed, isTrue);
          expect(returned, result);
          expect(tester.takeException(), isNull);
          BullSnackBar.dismiss();
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
