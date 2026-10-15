import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bb_mobile/features/exchange_settings/domain/entities/secure_file_upload.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_secure_file_upload_status_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/upload_exchange_document_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/secure_file_upload_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/ui/screens/secure_file_upload_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

const _rawReason =
    'ExchangeApiException[ERR_KYC_403]: recipient bc1qexamplerecipient rejected';

const _secureFileUpload = SecureFileUpload(
  userId: 'u-42',
  status: KycDocumentStatus.notUploaded,
);

class _MockGetUploadStatus extends Mock
    implements GetSecureFileUploadStatusUsecase {}

class _MockUploadDocument extends Mock
    implements UploadExchangeDocumentUsecase {}

Future<SecureFileUploadCubit> _pump(
  WidgetTester tester, {
  required Result<SecureFileUpload, ExchangeSettingsFailure> uploadStatus,
  Result<UploadExchangeDocumentOutcome, ExchangeSettingsFailure>? upload,
}) async {
  final getUploadStatus = _MockGetUploadStatus();
  when(getUploadStatus.execute).thenAnswer((_) async => uploadStatus);

  final uploadUsecase = _MockUploadDocument();
  if (upload != null) {
    when(
      () => uploadUsecase.execute(userId: any(named: 'userId')),
    ).thenAnswer((_) async => upload);
  }

  final cubit = SecureFileUploadCubit(
    getUploadStatusUsecase: getUploadStatus,
    uploadDocumentUsecase: uploadUsecase,
  );
  addTearDown(cubit.close);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SecureFileUploadScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    BlocProvider<SecureFileUploadCubit>.value(
      value: cubit,
      child: MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return cubit;
}

String _painted(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join(' | ');

void main() {
  testWidgets('an upload status load failure is shown translated', (
    tester,
  ) async {
    await _pump(
      tester,
      uploadStatus: const Err(
        ExchangeSettingsUploadStatusUnavailableFailure(_rawReason),
      ),
    );

    expect(
      find.text('Your upload status could not be loaded. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('the raw reason never reaches the screen', (tester) async {
    await _pump(
      tester,
      uploadStatus: const Err(
        ExchangeSettingsUploadStatusUnavailableFailure(_rawReason),
      ),
    );

    final painted = _painted(tester);
    expect(painted, isNot(contains('ERR_KYC_403')));
    expect(painted, isNot(contains('bc1qexamplerecipient')));
    expect(painted, isNot(contains('Exception')));
    expect(painted, isNotEmpty);
  });

  testWidgets('an upload rejection shows our copy, not the API sentence', (
    tester,
  ) async {
    final cubit = await _pump(
      tester,
      uploadStatus: const Err(
        ExchangeSettingsUploadStatusUnavailableFailure('no upload status yet'),
      ),
      upload: const Err(
        // The exchange's own sentence, as the use-case would carry it.
        ExchangeSettingsDocumentUploadFailure(_rawReason),
      ),
    );

    await cubit.pickAndUploadFile();
    await tester.pumpAndSettle();

    final painted = _painted(tester);
    expect(painted, isNot(contains('ERR_KYC_403')));
    expect(painted, isNot(contains('bc1qexamplerecipient')));
  });

  testWidgets('no failure means no error banner', (tester) async {
    await _pump(tester, uploadStatus: const Ok(_secureFileUpload));

    final painted = _painted(tester);
    expect(
      painted,
      isNot(contains('could not be loaded')),
      reason: 'a clean load must not paint an error',
    );
  });
}
