import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_onboarding_snapshot.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_initial_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/create_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_registration_name_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_state.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_onboarding_screen.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_restore_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:screen_privacy/screen_privacy.dart';

class _Create extends Mock implements CreateBullVaultOnboardingUsecase {}

class _Prepare extends Mock implements PrepareBullVaultTimeReferenceUsecase {}

class _Load extends Mock implements LoadBullVaultOnboardingUsecase {}

class _CheckBackups extends Mock
    implements CheckBullVaultMobileBackupsUsecase {}

class _UpdateSetup extends Mock implements UpdateBullVaultSetupUsecase {}

class _Activate extends Mock implements ActivateInitialBullVaultUsecase {}

class _Encode extends Mock implements EncodeBullVaultRecoveryPackageUsecase {}

class _UpdateName extends Mock
    implements UpdateBullVaultRegistrationNameUsecase {}

class _Restore extends Mock implements RestoreBullVaultUsecase {}

const _channel = MethodChannel('com.flutterplaza.no_screenshot_methods');

void main() {
  setUp(() => Device.screen = const Size(800, 600));
  for (final restoring in [false, true]) {
    final flow = restoring ? 'restore' : 'create';
    for (final response in [true, false, null, 'error']) {
      testWidgets('$flow waits for confirmed privacy ($response)', (
        tester,
      ) async {
        final protection = Completer<bool?>();
        final calls = <String>[];
        _installChannel(tester, protection, calls);
        await _open(tester, restoring: restoring);
        expect(calls, contains('screenshotOff'));
        expect(find.byType(TextField), findsNothing);

        if (response == 'error') {
          protection.completeError(PlatformException(code: 'unavailable'));
        } else {
          protection.complete(response as bool?);
        }
        await tester.pumpAndSettle();

        if (response == true) {
          final fields = find.byWidgetPredicate(
            (widget) => widget is TextField && widget.obscureText,
          );
          expect(fields, findsNWidgets(restoring ? 1 : 2));
          for (final field in fields.evaluate()) {
            expect(
              find.ancestor(
                of: find.byWidget(field.widget),
                matching: find.byType(ExcludeSemantics),
              ),
              findsWidgets,
            );
          }
          expect(find.byType(PrivacyUnavailableNotice), findsNothing);
          const passphrase = 'synthetic-passphrase-for-ui-test';
          await tester.enterText(fields.first, passphrase);
          if (!restoring) {
            await tester.enterText(fields.last, passphrase);
            final cubit = tester
                .element(fields.first)
                .read<BullVaultOnboardingCubit>();
            expect(cubit.state.mobilePassphraseReady, isTrue);
          }
          expect(
            tester.widget<TextField>(fields.first).controller!.text,
            passphrase,
          );
        } else {
          expect(find.byType(TextField), findsNothing);
          expect(find.byType(PrivacyUnavailableNotice), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(calls.last, 'screenshotOn');
      });
    }

    testWidgets('$flow can leave while protection is pending and retry', (
      tester,
    ) async {
      final protection = Completer<bool?>();
      final calls = <String>[];
      _installChannel(tester, protection, calls);
      await _open(tester, restoring: restoring);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      protection.complete(false);
      await tester.pumpAndSettle();
      expect(calls.last, 'screenshotOn');
      expect(tester.takeException(), isNull);

      final retry = Completer<bool?>()..complete(true);
      _installChannel(tester, retry, calls);
      await _open(tester, restoring: restoring);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(calls.last, 'screenshotOn');
    });

    testWidgets('$flow does not release another protected screen', (
      tester,
    ) async {
      final protection = Completer<bool?>()..complete(true);
      final calls = <String>[];
      _installChannel(tester, protection, calls);
      final controller = ScreenCaptureProtection.instance;
      await controller.acquire();
      await _open(tester, restoring: restoring);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(calls.last, 'screenshotOff');
      await controller.release();
      expect(calls.last, 'screenshotOn');
    });
  }
}

void _installChannel(
  WidgetTester tester,
  Completer<bool?> protection,
  List<String> calls,
) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
    call,
  ) async {
    calls.add(call.method);
    if (call.method == 'screenshotOff') return await protection.future;
    return true;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    ),
  );
}

Future<void> _open(WidgetTester tester, {required bool restoring}) async {
  final previousScreen = Device.screen;
  Device.screen = const Size(800, 600);
  addTearDown(() => Device.screen = previousScreen);
  final Widget screen;
  if (restoring) {
    final cubit = BullVaultRestoreCubit(_Restore());
    addTearDown(cubit.close);
    screen = BlocProvider<BullVaultRestoreCubit>.value(
      value: cubit,
      child: const BullVaultRestoreScreen(),
    );
  } else {
    final load = _Load();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinTestnet)),
    );
    final cubit = BullVaultOnboardingCubit(
      _Create(),
      _Prepare(),
      load,
      _CheckBackups(),
      _UpdateSetup(),
      _Activate(),
      _Encode(),
      _UpdateName(),
    );
    addTearDown(cubit.close);
    await cubit.load();
    cubit.setMobilePassphraseProtection(enabled: true);
    await cubit.next();
    cubit.setInheritance(false);
    await cubit.next();
    cubit.useGenericColdSigner();
    cubit.setColdInput('public-account-key');
    await cubit.next();
    expect(cubit.state.step, BullVaultOnboardingStep.mobilePassphrase);
    screen = BlocProvider<BullVaultOnboardingCubit>.value(
      value: cubit,
      child: const BullVaultOnboardingScreen(),
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen,
    ),
  );
  await tester.pump();
}
