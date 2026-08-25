import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_signing_key_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/signing_key_export_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/signing_key_export_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExportSigningKeyUsecase extends Mock
    implements ExportSigningKeyUsecase {}

void main() {
  testWidgets('keeps an account edit until it is submitted', (tester) async {
    final exportSigningKey = _MockExportSigningKeyUsecase();
    when(
      () => exportSigningKey.execute(account: any(named: 'account')),
    ).thenAnswer((invocation) async {
      final account = invocation.namedArguments[#account] as int;
      return Ok('signing-key-$account');
    });
    final cubit = SigningKeyExportCubit(
      exportSigningKeyUsecase: exportSigningKey,
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

    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '12',
    );
    expect(find.byType(QrDisplayWidget), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(cubit.state.account, 12);
    expect(cubit.state.descriptorKey, 'signing-key-12');
    expect(find.byType(QrDisplayWidget), findsOneWidget);
  });
}
