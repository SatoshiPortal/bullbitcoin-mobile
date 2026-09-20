import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/derive_vault_key_usecase.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/public/recoverbull_facade.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/features/recoverbull/ui/widgets/view_vault_key_warning_bottom_sheet.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Derive extends Mock implements DeriveVaultKeyUsecase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const privacyChannel = MethodChannel(
    'com.flutterplaza.no_screenshot_methods',
  );
  const key =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  late _Derive derive;
  late GoRouter router;
  setUp(() {
    derive = _Derive();
    locator.registerSingleton<DeriveVaultKeyUsecase>(derive);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, (_) async => true);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => RecoverBullFacade.openViewVaultKey(context),
              child: const Text('entry'),
            ),
          ),
        ),
        RecoverBullRouter.localKeyRoute,
        GoRoute(
          name: RecoverBullRoute.recoverbullFlows.name,
          path: RecoverBullRoute.recoverbullFlows.path,
          builder: (context, state) {
            final extra = state.extra! as RecoverBullFlowsExtra;
            expect(extra.flow, RecoverBullFlow.viewVaultKey);
            return const Scaffold(body: Text('existing server flow'));
          },
        ),
      ],
    );
  });
  tearDown(() async {
    router.dispose();
    await locator.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, null);
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.tap(find.text('entry'));
    await tester.pumpAndSettle();
    expect(find.byType(ViewVaultKeyWarningBottomSheet), findsOneWidget);
    verifyZeroInteractions(derive);
    final context = tester.element(find.byType(ViewVaultKeyWarningBottomSheet));
    final loc = AppLocalizations.of(context);
    await tester.tap(find.text(loc.sendContinue));
    await tester.pumpAndSettle();
    expect(find.text('existing server flow'), findsNothing);
    verifyZeroInteractions(derive);
  }

  testWidgets(
    'local entry needs no server and clears the previous key on retry',
    (tester) async {
      when(() => derive.execute()).thenAnswer((_) async => const Ok(key));
      await open(tester);
      await tester.tap(find.text('Choose backup file'));
      await tester.pumpAndSettle();
      expect(find.text(key), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(key),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      verify(() => derive.execute()).called(1);
      final pending = Completer<Result<String, RecoverBullFailure>>();
      when(() => derive.execute()).thenAnswer((_) => pending.future);
      await tester.tap(find.text('Choose backup file'));
      await tester.pump();
      expect(find.text(key), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Choose backup file'));
      verify(() => derive.execute()).called(1);
      pending.complete(const Err(VaultKeyPathUnavailableFailure()));
      await tester.pumpAndSettle();
      expect(find.text(key), findsNothing);
      await tester.tap(find.text('Use server instead'));
      await tester.pumpAndSettle();
      expect(find.text('existing server flow'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
