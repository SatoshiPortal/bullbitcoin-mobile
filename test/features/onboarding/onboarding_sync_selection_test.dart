import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_physical_recovery.dart';
import 'package:bb_mobile/features/wallet_sync/public/wallet_sync_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Create extends Mock implements CreateOnboardingWalletUsecase {}

class _Recover extends Mock implements RecoverOnboardingWalletUsecase {}

class _Choices extends Mock implements WalletSyncFacade {}

void main() {
  testWidgets(
    'double word submission opens choices once; cancel never recovers',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.flutterplaza.no_screenshot_methods'),
            (_) async => true,
          );
      final choices = _Choices();
      final pending = Completer<WalletSyncSelection?>();
      final recover = _Recover();
      final bloc = OnboardingBloc(
        createOnboardingWalletUsecase: _Create(),
        recoverOnboardingWalletUsecase: recover,
      );
      await locator.reset();
      locator.registerSingleton<WalletSyncFacade>(choices);
      addTearDown(locator.reset);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: bloc,
            child: const OnboardingPhysicalRecovery(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(MnemonicWidget));
      // The facade receives the recovery screen's context, not the child context.
      registerFallbackValue(context);
      when(() => choices.choose(any())).thenAnswer((_) => pending.future);
      // Empty words must fail locally before sync source selection.
      final recoverButton = find.text(
        AppLocalizations.of(context).onboardingRecover,
      );
      await tester.ensureVisible(recoverButton);
      await tester.tap(recoverButton);
      await tester.pumpAndSettle();
      verifyZeroInteractions(choices);
      verifyZeroInteractions(recover);
      final submit = tester
          .widget<MnemonicWidget>(find.byType(MnemonicWidget))
          .onSubmit;
      final publicInput = (
        words: <String>[],
        passphrase: '',
        label: '',
        language: bip39.Language.english,
      );
      final first = submit(publicInput) as Future<void>;
      final second = submit(publicInput) as Future<void>;
      await second;
      verify(() => choices.choose(any())).called(1);
      verifyZeroInteractions(recover);
      pending.complete(null);
      await first;
      await tester.pumpAndSettle();
      verifyZeroInteractions(recover);
      expect(bloc.state.onboardingStepStatus, OnboardingStepStatus.none);
    },
  );
}
