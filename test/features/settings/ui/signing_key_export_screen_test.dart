import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_signing_key_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/release_signing_key_account_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/signing_key_export_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/signing_key_export_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExportSigningKeyUsecase extends Mock
    implements ExportSigningKeyUsecase {}

class _MockReleaseSigningKeyAccountUsecase extends Mock
    implements ReleaseSigningKeyAccountUsecase {}

void main() {
  setUp(() => Device.screen = const Size(800, 600));
  for (final descriptionSaved in [true, false]) {
    testWidgets(
      'keeps edits, cancels usage and offers registration (description saved: $descriptionSaved)',
      (tester) async {
        final exportSigningKey = _MockExportSigningKeyUsecase();
        final releaseSigningKeyAccount = _MockReleaseSigningKeyAccountUsecase();
        when(
          releaseSigningKeyAccount.execute,
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => exportSigningKey.execute(
            account: any(named: 'account'),
            markUsed: any(named: 'markUsed'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((invocation) async {
          final account = invocation.namedArguments[#account] as int? ?? 0;
          final markUsed = invocation.namedArguments[#markUsed] as bool;
          if (markUsed) {
            return Ok((
              account: 1,
              descriptorKey: 'signing-key-1',
              isReserved: false,
              markedAccount: account,
              descriptionSaved: descriptionSaved,
              usedAccounts: [
                UsedSigningKeyAccount(
                  account: account,
                  source: descriptionSaved
                      ? UsedSigningKeySource.memo
                      : UsedSigningKeySource.legacy,
                  description: descriptionSaved ? 'Family vault' : null,
                ),
              ],
              usedAccountsIncomplete: false,
            ));
          }
          return Ok((
            account: account,
            descriptorKey: 'signing-key-$account',
            isReserved: false,
            markedAccount: null,
            descriptionSaved: true,
            usedAccounts: <UsedSigningKeyAccount>[],
            usedAccountsIncomplete: false,
          ));
        });
        final cubit = SigningKeyExportCubit(
          exportSigningKeyUsecase: exportSigningKey,
          releaseSigningKeyAccountUsecase: releaseSigningKeyAccount,
        );
        addTearDown(cubit.close);
        await cubit.load();

        var registrationOffered = false;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => BlocProvider.value(
                value: cubit,
                child: SigningKeyExportScreen(
                  onRegisterDescriptor: () => registrationOffered = true,
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );

        expect(find.text('Keys already used'), findsOneWidget);
        expect(find.text('No keys handed out yet'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(cubit.state.account, 0);
        expect(cubit.state.descriptorKey, 'signing-key-0');
        expect(find.text('0'), findsOneWidget);
        expect(find.byType(QrDisplayWidget), findsOneWidget);

        await tester.enterText(find.byType(TextField), '12');
        await tester.pump();

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          '12',
        );
        await tester.pumpAndSettle();

        expect(cubit.state.account, 12);
        expect(cubit.state.descriptorKey, 'signing-key-12');
        expect(find.byType(QrDisplayWidget), findsOneWidget);

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        final markUsed = find.text('I used this key').first;
        await tester.tap(markUsed);
        await tester.pumpAndSettle();
        expect(find.text('Where did you use this key?'), findsWidgets);
        expect(cubit.state.markedAccount, isNull);
        router.pop();
        await tester.pumpAndSettle();
        expect(cubit.state.account, 12);
        expect(cubit.state.markedAccount, isNull);
        await tester.tap(markUsed);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Family vault');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        verify(
          () => exportSigningKey.execute(
            account: 12,
            markUsed: true,
            description: 'Family vault',
          ),
        ).called(1);
        expect(cubit.state.account, 1);
        expect(cubit.state.markedAccount, 12);
        await tester.drag(find.byType(ListView), const Offset(0, 1400));
        await tester.pumpAndSettle();
        expect(
          find.text(
            descriptionSaved
                ? 'Account 12 — Family vault'
                : 'Account 12 — Used, no description',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Account 12 is marked as used'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Register wallet descriptor'));
        await tester.tap(find.text('Register wallet descriptor'));
        expect(registrationOffered, isTrue);
        expect(
          find.text(
            'The key is marked as used, but its description could not be saved.',
          ),
          descriptionSaved ? findsNothing : findsOneWidget,
        );
      },
    );
  }

  testWidgets('warns before showing a reserved account key', (tester) async {
    final exportSigningKey = _MockExportSigningKeyUsecase();
    final releaseSigningKeyAccount = _MockReleaseSigningKeyAccountUsecase();
    when(
      releaseSigningKeyAccount.execute,
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => exportSigningKey.execute(
        account: any(named: 'account'),
        markUsed: any(named: 'markUsed'),
        description: any(named: 'description'),
      ),
    ).thenAnswer(
      (_) async => const Ok((
        account: 7,
        descriptorKey: 'reserved-signing-key',
        isReserved: true,
        markedAccount: null,
        descriptionSaved: true,
        usedAccounts: <UsedSigningKeyAccount>[],
        usedAccountsIncomplete: false,
      )),
    );
    final cubit = SigningKeyExportCubit(
      exportSigningKeyUsecase: exportSigningKey,
      releaseSigningKeyAccountUsecase: releaseSigningKeyAccount,
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const SigningKeyExportScreen(),
        ),
      ),
    );

    expect(find.textContaining('already marked as used'), findsOneWidget);
    expect(find.byType(QrDisplayWidget), findsNothing);

    await tester.tap(find.text('Show key details'));
    await tester.pump();

    expect(find.byType(QrDisplayWidget), findsOneWidget);
    expect(find.text('I used this key'), findsNothing);
  });
  testWidgets('shows used rows in order and selects the tapped account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final export = _MockExportSigningKeyUsecase();
    final release = _MockReleaseSigningKeyAccountUsecase();
    when(release.execute).thenAnswer((_) async => const Ok(null));
    const rows = [
      UsedSigningKeyAccount(
        account: 0,
        source: UsedSigningKeySource.wallet,
        description: 'Home vault',
      ),
      UsedSigningKeyAccount(
        account: 1,
        source: UsedSigningKeySource.memo,
        description: 'Cold key',
      ),
      UsedSigningKeyAccount(
        account: 2,
        source: UsedSigningKeySource.memo,
        description: 'Inheritance key',
      ),
    ];
    when(
      () => export.execute(
        account: any(named: 'account'),
        markUsed: any(named: 'markUsed'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((invocation) async {
      final account = invocation.namedArguments[#account] as int? ?? 3;
      return Ok((
        account: account,
        descriptorKey: 'key-$account',
        isReserved: account < 3,
        markedAccount: null,
        descriptionSaved: true,
        usedAccounts: rows,
        usedAccountsIncomplete: false,
      ));
    });
    final cubit = SigningKeyExportCubit(
      exportSigningKeyUsecase: export,
      releaseSigningKeyAccountUsecase: release,
    );
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const SigningKeyExportScreen(),
        ),
      ),
    );
    final wallet = find.text('Account 0 — Home vault');
    final cold = find.text('Account 1 — Cold key');
    final heir = find.text('Account 2 — Inheritance key');
    expect(tester.getTopLeft(wallet).dy, lessThan(tester.getTopLeft(cold).dy));
    expect(tester.getTopLeft(cold).dy, lessThan(tester.getTopLeft(heir).dy));
    expect(
      tester.getTopLeft(heir).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
    expect(cubit.state.account, 3);
    await tester.tap(cold);
    await tester.pumpAndSettle();
    expect(cubit.state.account, 1);
    expect(cubit.state.isReserved, isTrue);
    expect(find.byType(QrDisplayWidget), findsNothing);
  });

  testWidgets('does not present an incomplete empty list as unused keys', (
    tester,
  ) async {
    final export = _MockExportSigningKeyUsecase();
    final release = _MockReleaseSigningKeyAccountUsecase();
    when(release.execute).thenAnswer((_) async => const Ok(null));
    when(
      () => export.execute(
        account: any(named: 'account'),
        markUsed: any(named: 'markUsed'),
        description: any(named: 'description'),
      ),
    ).thenAnswer(
      (_) async => const Ok((
        account: 0,
        descriptorKey: 'key-0',
        isReserved: false,
        markedAccount: null,
        descriptionSaved: true,
        usedAccounts: <UsedSigningKeyAccount>[],
        usedAccountsIncomplete: true,
      )),
    );
    final cubit = SigningKeyExportCubit(
      exportSigningKeyUsecase: export,
      releaseSigningKeyAccountUsecase: release,
    );
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const SigningKeyExportScreen(),
        ),
      ),
    );
    expect(find.text('Some records could not be read'), findsOneWidget);
    expect(find.text('No keys handed out yet'), findsNothing);
  });
}
