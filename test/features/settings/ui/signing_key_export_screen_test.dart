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
  testWidgets('shows the suggested account and keeps submitted edits', (
    tester,
  ) async {
    final exportSigningKey = _MockExportSigningKeyUsecase();
    final releaseSigningKeyAccount = _MockReleaseSigningKeyAccountUsecase();
    when(
      releaseSigningKeyAccount.execute,
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => exportSigningKey.execute(
        account: any(named: 'account'),
        markUsed: any(named: 'markUsed'),
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
        ));
      }
      return Ok((
        account: account,
        descriptorKey: 'signing-key-$account',
        isReserved: false,
        markedAccount: null,
      ));
    });
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
    await tester.pump();

    expect(cubit.state.account, 1);
    expect(cubit.state.markedAccount, 12);
    expect(find.textContaining('Account 12 is marked as used'), findsOneWidget);
  });

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
      ),
    ).thenAnswer(
      (_) async => const Ok((
        account: 7,
        descriptorKey: 'reserved-signing-key',
        isReserved: true,
        markedAccount: null,
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
}
