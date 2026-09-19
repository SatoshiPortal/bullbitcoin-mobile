import 'dart:async';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/update_data_backup_lifecycle_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/main.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinLifecycle extends Mock implements PayjoinLifecycle {}

class _Startup extends Mock implements AppStartupBloc {}

class _Wallets extends Mock implements WalletBloc {}

class _BackupLifecycle extends Mock
    implements UpdateDataBackupLifecycleUsecase {}

void main() {
  testWidgets(
    'app backup scope follows wallet creation and deletion after initial startup',
    (tester) async {
      final startup = _Startup();
      final wallets = _Wallets();
      final lifecycle = _BackupLifecycle();
      final changes = StreamController<WalletState>.broadcast(sync: true);
      var current = const WalletState();
      when(
        () => startup.state,
      ).thenReturn(const AppStartupSuccess(hasDefaultWallets: false));
      when(() => startup.stream).thenAnswer((_) => const Stream.empty());
      when(() => wallets.state).thenAnswer((_) => current);
      when(() => wallets.stream).thenAnswer((_) => changes.stream);
      when(() => lifecycle.changes).thenAnswer((_) => const Stream.empty());
      when(
        () => lifecycle.execute(
          ready: any(named: 'ready'),
          foreground: any(named: 'foreground'),
        ),
      ).thenAnswer((_) async {});
      locator.registerSingleton<UpdateDataBackupLifecycleUsecase>(lifecycle);
      addTearDown(() async {
        await changes.close();
        await locator.reset();
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AppStartupBloc>.value(value: startup),
            BlocProvider<WalletBloc>.value(value: wallets),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) =>
                  buildBackupSettingsScope(context, const SizedBox.shrink()),
            ),
          ),
        ),
      );
      verify(() => lifecycle.execute(ready: false, foreground: true)).called(1);
      current = WalletState(
        wallets: [
          Wallet(
            origin: 'default',
            network: Network.bitcoinMainnet,
            isDefault: true,
            balanceSat: BigInt.zero,
            signers: [],
            scriptType: ScriptType.bip84,
            publicDescriptor: 'wpkh(xpub/<0;1>/*)',
          ),
        ],
      );
      changes.add(current);
      await tester.pump();
      verify(() => lifecycle.execute(ready: true, foreground: true)).called(1);
      current = const WalletState();
      changes.add(current);
      await tester.pump();
      verify(() => lifecycle.execute(ready: false, foreground: true)).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('resumes Payjoin recovery when the app returns to the foreground', () {
    final lifecycle = _MockPayjoinLifecycle();
    when(lifecycle.resume).thenAnswer((_) async => const Ok(null));

    resumePayjoinsOnAppResume(AppLifecycleState.paused, lifecycle);
    verifyNever(lifecycle.resume);

    resumePayjoinsOnAppResume(AppLifecycleState.resumed, lifecycle);
    verify(lifecycle.resume).called(1);
  });
}
