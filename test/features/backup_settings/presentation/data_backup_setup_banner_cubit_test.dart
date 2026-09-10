import 'dart:async';

import 'package:bb_mobile/features/backup_settings/presentation/data_backup_setup_banner_cubit.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

WalletBackupState _state(WalletBackupRecoveryState recovery) =>
    WalletBackupState(
      enabled: false,
      localRevision: 0,
      uploadedRevision: 0,
      lastSucceededAt: null,
      unsupportedVersion: null,
      recoveryState: recovery,
    );

void main() {
  late StreamController<Result<WalletBackupState, WalletBackupFailure>> states;
  late bool pending;
  late Completer<Result<void, WizardFailure>> apply;
  late int applyCalls;
  late List<Set<String>> recoveryContexts;

  DataBackupSetupBannerCubit cubit() => DataBackupSetupBannerCubit(
    hasPendingChoices: () async => pending,
    applyPendingChoices: ({Set<String> defaultCreatedWalletIds = const {}}) {
      applyCalls++;
      recoveryContexts.add(defaultCreatedWalletIds);
      return apply.future;
    },
    watchState: () => states.stream,
  );

  setUp(() {
    states = StreamController.broadcast();
    pending = true;
    apply = Completer();
    applyCalls = 0;
    recoveryContexts = [];
  });

  tearDown(() => states.close());

  test('stays hidden when the wizard left nothing to apply', () async {
    pending = false;
    final c = cubit();
    addTearDown(c.close);

    await c.start();

    expect(c.state, isA<DataBackupSetupHidden>());
    expect(applyCalls, 0);
  });

  test('shows setup while the opt-in is applied, then hides', () async {
    final c = cubit();
    addTearDown(c.close);

    final started = c.start();
    await pumpEventQueue();
    expect(c.state, isA<DataBackupSettingUp>());

    apply.complete(const Ok(null));
    await started;

    expect(c.state, isA<DataBackupSetupHidden>());
    expect(applyCalls, 1);
  });

  test('shows restoring while a snapshot is being written', () async {
    final c = cubit();
    addTearDown(c.close);
    final started = c.start();
    await pumpEventQueue();

    states.add(Ok(_state(WalletBackupRecoveryState.applying)));
    await pumpEventQueue();
    expect(c.state, isA<DataBackupRestoring>());

    states.add(Ok(_state(WalletBackupRecoveryState.idle)));
    await pumpEventQueue();
    expect(c.state, isA<DataBackupSettingUp>());

    apply.complete(const Ok(null));
    await started;
    expect(c.state, isA<DataBackupSetupHidden>());
  });

  test('a refused opt-in is shown and can be retried', () async {
    final c = cubit();
    addTearDown(c.close);
    apply.complete(const Err(WizardApplyFailure()));

    await c.start();
    expect(c.state, isA<DataBackupSetupFailed>());

    apply = Completer()..complete(const Ok(null));
    await c.applyPendingChoices();

    expect(c.state, isA<DataBackupSetupHidden>());
    expect(applyCalls, 2);
  });

  test('forwards new wallet IDs only for the initial attempt', () async {
    final c = cubit();
    addTearDown(c.close);
    apply.complete(const Err(WizardApplyFailure()));
    await c.start(defaultCreatedWalletIds: {'fresh-wallet'});
    apply = Completer()..complete(const Ok(null));
    await c.applyPendingChoices();
    expect(recoveryContexts, [
      {'fresh-wallet'},
      <String>{},
    ]);
    expect(c.state, isA<DataBackupSetupHidden>());
  });

  test(
    'closing does not start recovery while subscription cleanup is pending',
    () async {
      final pendingCheck = Completer<bool>();
      final cancellation = Completer<void>();
      final watched =
          StreamController<Result<WalletBackupState, WalletBackupFailure>>(
            onCancel: () => cancellation.future,
          );
      var calls = 0;
      final c = DataBackupSetupBannerCubit(
        hasPendingChoices: () => pendingCheck.future,
        applyPendingChoices:
            ({Set<String> defaultCreatedWalletIds = const {}}) async {
              calls++;
              return const Ok(null);
            },
        watchState: () => watched.stream,
      );
      final started = c.start(defaultCreatedWalletIds: {'fresh'});
      final closing = c.close();
      pendingCheck.complete(true);
      await pumpEventQueue();
      expect(calls, 0);
      cancellation.complete();
      await closing;
      await started;
      await watched.close();
    },
  );

  test('concurrent starts do not duplicate setup', () async {
    final c = cubit();
    addTearDown(c.close);
    final first = c.start(defaultCreatedWalletIds: {'fresh-wallet'});
    final second = c.start();
    await pumpEventQueue();
    expect(applyCalls, 1);
    apply.complete(const Ok(null));
    await Future.wait([first, second]);
    expect(recoveryContexts, [
      {'fresh-wallet'},
    ]);
  });
}
