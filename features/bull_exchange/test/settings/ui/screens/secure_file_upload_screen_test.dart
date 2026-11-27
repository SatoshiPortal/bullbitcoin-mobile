import 'package:exchange/exchange.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/settings/domain/exchange_settings_failure.dart';
import 'package:bull_exchange/src/settings/domain/entities/secure_file_upload.dart';
import 'package:bull_exchange/src/settings/domain/entities/exchange_document_to_upload.dart';
import 'package:bull_exchange/src/settings/presentation/secure_file_upload_bloc.dart';
import 'package:bull_exchange/src/settings/domain/secure_file_upload_machine.dart';
import 'package:bull_exchange/src/settings/ui/screens/secure_file_upload_screen.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';

import '../../settings_usecase_fakes.dart';

const _rawReason =
    'ExchangeApiException[ERR_KYC_403]: recipient bc1qexamplerecipient rejected';

const _secureFileUpload = SecureFileUpload(
  userId: 'u-42',
  status: KycDocumentStatus.notUploaded,
);

const _document = ExchangeDocumentToUpload(bytes: [1], fileName: 'doc-u-42-ID');

Future<SecureUploadBloc> _pump(
  WidgetTester tester, {
  required Result<SecureFileUpload, ExchangeSettingsFailure> uploadStatus,
  Result<void, ExchangeSettingsFailure>? upload,
}) async {
  final cubit = SecureUploadBloc(
    session: const ExchangeSession(
      environment: ExchangeEnvironment.mainnet,
      epoch: 1,
      sessionId: 's',
    ),
    getUploadStatus: FakeGetSecureFileUploadStatusUsecase(
      () async => uploadStatus,
    ),
    pickDocument: FakePickExchangeDocumentUsecase(({userId}) async {
      // The account's user id names the document (doc-<userId>-ID).
      if (upload == null || userId != 'u-42') {
        throw StateError('pick for $userId was not expected');
      }
      return const Ok(_document);
    }),
    uploadDocument: FakeUploadExchangeDocumentUsecase((document) async {
      if (upload == null || document != _document) {
        throw StateError('upload of $document was not expected');
      }
      return upload;
    }),
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
    BlocProvider<SecureUploadBloc>.value(
      value: cubit,
      child: MaterialApp.router(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
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
    final bloc = await _pump(
      tester,
      uploadStatus: const Ok(_secureFileUpload),
      upload: const Err(
        // The exchange's own sentence, as the use-case would carry it.
        ExchangeSettingsDocumentUploadFailure(_rawReason),
      ),
    );

    bloc.add(const UploadPressed());
    await tester.pumpAndSettle();

    expect(bloc.state, isA<UploadReady>());
    final painted = _painted(tester);
    expect(painted, isNot(contains('ERR_KYC_403')));
    expect(painted, isNot(contains('bc1qexamplerecipient')));
  });

  testWidgets('a failed status load offers Retry, never an upload (SET-1)', (
    tester,
  ) async {
    final bloc = await _pump(
      tester,
      uploadStatus: const Err(
        ExchangeSettingsUploadStatusUnavailableFailure('no upload status yet'),
      ),
    );

    expect(bloc.state, isA<UploadStatusFailed>());
    bloc.add(const UploadPressed());
    await tester.pumpAndSettle();
    expect(bloc.state, isA<UploadStatusFailed>());
  });

  testWidgets('every upload is confirmed, not only the first (SET-4)', (
    tester,
  ) async {
    const rejected = SecureFileUpload(
      userId: 'u-42',
      status: KycDocumentStatus.rejected,
    );
    final bloc = await _pump(
      tester,
      uploadStatus: const Ok(rejected),
      upload: const Ok(null),
    );
    var confirmations = 0;
    final subscription = bloc.stream.listen((state) {
      if (state is UploadDone) confirmations++;
    });
    addTearDown(subscription.cancel);

    for (var i = 0; i < 2; i++) {
      bloc.add(const UploadPressed());
      await tester.pumpAndSettle();
      expect(bloc.state, isA<UploadReady>());
    }
    expect(confirmations, 2);
    // Let the confirmation snackbar time out so no timer outlives the test.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
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
