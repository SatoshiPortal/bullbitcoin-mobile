import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_stats_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/upload_kyc_document_usecase.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_settings/domain/document_picker_port.dart';
import 'package:bb_mobile/features/exchange_settings/domain/entities/account_info.dart';
import 'package:bb_mobile/features/exchange_settings/domain/entities/exchange_preferences.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bb_mobile/features/exchange_settings/domain/entities/secure_file_upload.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_account_info_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_statistics_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_secure_file_upload_status_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/update_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/upload_exchange_document_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The kind of text the exchange API and the SDKs put in an exception: a
/// sentence plus an identifier that must never be rendered.
const _rawReason =
    'ExchangeApiException[ERR_KYC_403]: recipient bc1qexamplerecipient rejected';

class _MockGetOrderStats extends Mock implements GetOrderStatsUsecase {}

class _MockGetUserSummary extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockUploadKycDocument extends Mock implements UploadKycDocumentUsecase {}

class _MockExchangeFacade extends Mock implements ExchangeFacade {}

UserSummary _summary({List<String> groups = const []}) => UserSummary(
  userNumber: 7,
  userId: 'u-42',
  groups: groups,
  profile: const UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: const [],
  language: 'FR',
  currency: 'EUR',
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
  emailNotificationsEnabled: false,
);

/// Answers the picker with a fixed outcome.
class _StubPicker implements DocumentPickerPort {
  final Result<PickedDocument?, ExchangeSettingsFailure> result;
  int calls = 0;

  _StubPicker(this.result);

  @override
  Future<Result<PickedDocument?, ExchangeSettingsFailure>> pick({
    required List<String> allowedExtensions,
  }) async {
    calls++;
    return result;
  }
}

PickedDocument _document({
  String name = 'id.png',
  String? extension = 'png',
  int sizeBytes = 1024,
  List<int>? bytes = const [1, 2, 3],
}) => PickedDocument(
  name: name,
  extension: extension,
  sizeBytes: sizeBytes,
  bytes: bytes,
);

/// Asserts a failure carries nothing that could identify the user or the API.
void _expectSanitized(ExchangeSettingsFailure failure) {
  final log = failure.logMessage ?? '';
  expect(log, isNot(contains('bc1qexamplerecipient')));
  expect(log, isNot(contains('ERR_KYC_403')));
  expect(log, isNot(contains('rejected')));
}

void main() {
  setUpAll(() {
    // `any(named:)` needs a fallback for every non-primitive parameter type.
    registerFallbackValue(<int>[]);
  });

  group('GetExchangeStatisticsUsecase', () {
    test('a throwing core use-case becomes a sanitized failure', () async {
      final core = _MockGetOrderStats();
      when(core.execute).thenThrow(Exception(_rawReason));

      final result = await GetExchangeStatisticsUsecase(
        getOrderStatsUsecase: core,
      ).execute();

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsStatisticsUnavailableFailure>());
      _expectSanitized(failure);
    });
  });

  group('GetAccountInfoUsecase', () {
    test('maps the user summary to the account info', () async {
      final core = _MockGetUserSummary();
      when(
        core.execute,
      ).thenAnswer((_) async => _summary(groups: ['KYC_LIGHT_VERIFICATION']));

      final result = await GetAccountInfoUsecase(
        getExchangeUserSummaryUsecase: core,
      ).execute();

      final info = (result as Ok<AccountInfo, ExchangeSettingsFailure>).value;
      expect(info.userNumber, 7);
      expect(info.email, 'sat@example.com');
      expect(info.firstName, 'Sat');
      expect(info.lastName, 'Oshi');
      expect(info.verificationLevel, VerificationLevel.light);
    });

    test('the highest KYC group wins', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenAnswer(
        (_) async => _summary(
          groups: ['KYC_LIMITED_VERIFICATION', 'KYC_IDENTITY_VERIFIED'],
        ),
      );

      final result = await GetAccountInfoUsecase(
        getExchangeUserSummaryUsecase: core,
      ).execute();

      expect(
        (result as Ok<AccountInfo, ExchangeSettingsFailure>)
            .value
            .verificationLevel,
        VerificationLevel.identityVerified,
      );
    });

    test('no KYC group means not verified', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenAnswer((_) async => _summary());

      final result = await GetAccountInfoUsecase(
        getExchangeUserSummaryUsecase: core,
      ).execute();

      expect(
        (result as Ok<AccountInfo, ExchangeSettingsFailure>)
            .value
            .verificationLevel,
        VerificationLevel.notVerified,
      );
    });

    test('a throwing core use-case becomes a sanitized failure', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenThrow(Exception(_rawReason));

      final result = await GetAccountInfoUsecase(
        getExchangeUserSummaryUsecase: core,
      ).execute();

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsAccountUnavailableFailure>());
      _expectSanitized(failure);
    });
  });

  group('GetExchangePreferencesUsecase', () {
    test('maps the user summary to the preferences', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenAnswer((_) async => _summary());

      final result = await GetExchangePreferencesUsecase(
        getExchangeUserSummaryUsecase: core,
      ).execute();

      final preferences =
          (result as Ok<ExchangePreferences, ExchangeSettingsFailure>).value;
      expect(preferences.language, 'FR');
      expect(preferences.currency, 'EUR');
      expect(preferences.emailNotificationsEnabled, isFalse);
    });

    test('a throwing core use-case becomes a sanitized failure', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenThrow(Exception(_rawReason));

      final result = await GetExchangePreferencesUsecase(
        getExchangeUserSummaryUsecase: core,
      ).execute();

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsAccountUnavailableFailure>());
      _expectSanitized(failure);
    });
  });

  group('UpdateExchangePreferencesUsecase', () {
    const preferences = ExchangePreferences(
      language: 'FR',
      currency: 'EUR',
      emailNotificationsEnabled: true,
    );

    void stubSave(_MockExchangeFacade facade, Result<void, ExchangeFailure> r) {
      when(
        () => facade.savePreferences(
          language: any(named: 'language'),
          currency: any(named: 'currency'),
          emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
        ),
      ).thenAnswer((_) async => r);
    }

    test('passes the edited preferences to the exchange', () async {
      final facade = _MockExchangeFacade();
      stubSave(facade, const Ok(null));

      final result = await UpdateExchangePreferencesUsecase(
        exchangeFacade: facade,
      ).execute(preferences);

      expect(result, isA<Ok<void, ExchangeSettingsFailure>>());
      verify(
        () => facade.savePreferences(
          language: 'FR',
          currency: 'EUR',
          emailNotificationsEnabled: true,
        ),
      ).called(1);
    });

    test('a network failure stays a network failure', () async {
      final facade = _MockExchangeFacade();
      stubSave(facade, const Err(ExchangeNetworkFailure('offline')));

      final result = await UpdateExchangePreferencesUsecase(
        exchangeFacade: facade,
      ).execute(preferences);

      expect((result as Err).failure, isA<ExchangeSettingsNetworkFailure>());
    });

    test('a missing session stays a not-authenticated failure', () async {
      final facade = _MockExchangeFacade();
      stubSave(facade, const Err(ExchangeNotAuthenticatedFailure('expired')));

      final result = await UpdateExchangePreferencesUsecase(
        exchangeFacade: facade,
      ).execute(preferences);

      expect(
        (result as Err).failure,
        isA<ExchangeSettingsNotAuthenticatedFailure>(),
      );
    });

    test('any other exchange failure becomes a save failure', () async {
      final facade = _MockExchangeFacade();
      stubSave(facade, const Err(ExchangePreferencesSaveFailure('rejected')));

      final result = await UpdateExchangePreferencesUsecase(
        exchangeFacade: facade,
      ).execute(preferences);

      expect(
        (result as Err).failure,
        isA<ExchangeSettingsPreferencesSaveFailure>(),
      );
    });
  });

  group('GetSecureFileUploadStatusUsecase', () {
    test('maps the user summary to the upload status', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenAnswer(
        (_) async => const UserSummary(
          userNumber: 1,
          userId: 'u-42',
          groups: [],
          profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
          email: 'sat@example.com',
          balances: [],
          dca: UserDca(isActive: false),
          autoBuy: UserAutoBuy(
            isActive: false,
            addresses: UserAutoBuyAddresses(),
          ),
          kycDocumentStatus: UserKycDocumentStatus(
            secureFileUpload: KycDocumentStatus.underReview,
            documents: UserKycDocuments(
              id: KycDocumentStatus.accepted,
              proofOfResidence: KycDocumentStatus.accepted,
              selfie: KycDocumentStatus.accepted,
            ),
          ),
        ),
      );

      final result = await GetSecureFileUploadStatusUsecase(
        getExchangeUserSummaryUsecase: core,
      ).execute();

      final upload =
          (result as Ok<SecureFileUpload, ExchangeSettingsFailure>).value;
      expect(upload.userId, 'u-42');
      expect(upload.status, KycDocumentStatus.underReview);
    });

    test('a throwing core use-case becomes a sanitized failure', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenThrow(Exception(_rawReason));

      final result = await GetSecureFileUploadStatusUsecase(
        getExchangeUserSummaryUsecase: core,
      ).execute();

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsUploadStatusUnavailableFailure>());
      _expectSanitized(failure);
    });
  });

  group('UploadExchangeDocumentUsecase', () {
    UploadExchangeDocumentUsecase build(
      DocumentPickerPort picker,
      UploadKycDocumentUsecase upload,
    ) => UploadExchangeDocumentUsecase(
      documentPicker: picker,
      uploadKycDocumentUsecase: upload,
    );

    test('a dismissed picker is a cancellation, not a failure', () async {
      final result = await build(
        _StubPicker(const Ok(null)),
        _MockUploadKycDocument(),
      ).execute();

      expect((result as Ok).value, isA<ExchangeDocumentPickCancelled>());
    });

    test('an empty file is rejected before upload', () async {
      final upload = _MockUploadKycDocument();

      final result = await build(
        _StubPicker(Ok(_document(bytes: const []))),
        upload,
      ).execute();

      expect(
        (result as Err).failure,
        isA<ExchangeSettingsDocumentEmptyFailure>(),
      );
      verifyNever(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: any(named: 'fileName'),
        ),
      );
    });

    test('a file the picker could not read is unreadable, not empty', () async {
      final upload = _MockUploadKycDocument();

      final result = await build(
        _StubPicker(Ok(_document(bytes: null))),
        upload,
      ).execute();

      expect(
        (result as Err).failure,
        isA<ExchangeSettingsDocumentUnreadableFailure>(),
        reason: 'no bytes means unreadable; an empty list means empty',
      );
      verifyNever(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: any(named: 'fileName'),
        ),
      );
    });

    test('an uppercase extension is accepted', () async {
      final upload = _MockUploadKycDocument();
      when(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: any(named: 'fileName'),
        ),
      ).thenAnswer((_) async => FileUploadResult.success());

      final result = await build(
        _StubPicker(Ok(_document(name: 'ID.PNG', extension: 'PNG'))),
        upload,
      ).execute();

      expect(
        (result as Ok).value,
        isA<ExchangeDocumentUploaded>(),
        reason: 'the domain rule must not depend on the adapter lowercasing',
      );
    });

    test('an oversized file is rejected before upload', () async {
      final upload = _MockUploadKycDocument();

      final result = await build(
        _StubPicker(
          Ok(_document(sizeBytes: FileToUpload.maxFileSizeBytes + 1)),
        ),
        upload,
      ).execute();

      expect(
        (result as Err).failure,
        isA<ExchangeSettingsDocumentTooLargeFailure>(),
      );
      verifyNever(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: any(named: 'fileName'),
        ),
      );
    });

    test('a disallowed extension is rejected before upload', () async {
      final upload = _MockUploadKycDocument();

      final result = await build(
        _StubPicker(Ok(_document(name: 'payload.exe', extension: 'exe'))),
        upload,
      ).execute();

      expect(
        (result as Err).failure,
        isA<ExchangeSettingsDocumentTypeNotAllowedFailure>(),
      );
      verifyNever(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: any(named: 'fileName'),
        ),
      );
    });

    // The exchange's own sentence is the leak this migration exists to stop.
    test('a rejected upload keeps the API sentence in logMessage', () async {
      final upload = _MockUploadKycDocument();
      when(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: any(named: 'fileName'),
        ),
      ).thenAnswer((_) async => FileUploadResult.failure(_rawReason));

      final result = await build(
        _StubPicker(Ok(_document())),
        upload,
      ).execute();

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsDocumentUploadFailure>());
      // Kept for diagnosis — safe only because the l10n extension never reads
      // it, which exchange_settings_failure_l10n_test.dart asserts.
      expect(failure.logMessage, _rawReason);
    });

    test('a throwing upload becomes a sanitized failure', () async {
      final upload = _MockUploadKycDocument();
      when(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: any(named: 'fileName'),
        ),
      ).thenThrow(Exception(_rawReason));

      final result = await build(
        _StubPicker(Ok(_document())),
        upload,
      ).execute();

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsDocumentUploadFailure>());
      _expectSanitized(failure);
    });

    test('a picker failure short-circuits without uploading', () async {
      final upload = _MockUploadKycDocument();
      final picker = _StubPicker(
        const Err(
          ExchangeSettingsDocumentUnreadableFailure('pickFiles blew up'),
        ),
      );

      final result = await build(picker, upload).execute();

      expect(
        (result as Err).failure,
        isA<ExchangeSettingsDocumentUnreadableFailure>(),
      );
      verifyNever(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: any(named: 'fileName'),
        ),
      );
    });

    test('the standardized filename is used when a userId is known', () async {
      final upload = _MockUploadKycDocument();
      when(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: any(named: 'fileName'),
        ),
      ).thenAnswer((_) async => FileUploadResult.success());

      final result = await build(
        _StubPicker(Ok(_document())),
        upload,
      ).execute(userId: 'u-42');

      expect((result as Ok).value, isA<ExchangeDocumentUploaded>());
      verify(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: 'doc-u-42-ID',
        ),
      ).called(1);
    });
  });
}
