import 'dart:typed_data';

import 'package:bb_mobile/features/exchange_settings/domain/entities/file_upload.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:file_system/file_system.dart';
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

class _MockGetUserSummary extends Mock
    implements GetExchangeUserSummaryUsecase {}

abstract interface class _Upload {
  Future<Result<void, ExchangeFailure>> execute({
    required List<int> fileBytes,
    required String fileName,
  });
}

class _MockUploadKycDocument extends Mock implements _Upload {}

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

/// Answers the picker and reader with fixed outcomes.
class _StubPicker extends Fake implements FileSystem {
  final Result<PickedDocument?, FileSystemFailure> result;

  _StubPicker(this.result);

  @override
  Future<Result<PickedDocument?, FileSystemFailure>> pick({
    List<String> allowedExtensions = const [],
  }) async => result;

  @override
  Future<Result<Uint8List, FileSystemFailure>> read(
    PickedDocument document, {
    required int maxBytes,
  }) async {
    final bytes = (document as _Document).bytes;
    if (bytes == null) {
      return const Err(FileSystemReadFailure());
    }
    if (bytes.length > maxBytes) {
      return const Err(FileSystemTooLargeFailure());
    }
    return Ok(Uint8List.fromList(bytes));
  }
}

class _Document extends Fake implements PickedDocument {
  @override
  final String name;
  @override
  final String? extension;
  final List<int>? bytes;

  _Document({
    this.name = 'id.png',
    this.extension = 'png',
    this.bytes = const [1, 2, 3],
  });
}

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
    test('an Exchange statistics failure stays sanitized', () async {
      final result = await GetExchangeStatisticsUsecase(
        exchange: exchangeForTesting(
          getOrderStats: () async =>
              const Err(ExchangeStatisticsUnavailableFailure(_rawReason)),
        ),
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
    UploadExchangeDocumentUsecase build(FileSystem picker, _Upload upload) =>
        UploadExchangeDocumentUsecase(
          fileSystem: picker,
          exchange: exchangeForTesting(uploadKycDocument: upload.execute),
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
        _StubPicker(Ok(_Document(bytes: const []))),
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
        _StubPicker(Ok(_Document(bytes: null))),
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
      ).thenAnswer((_) async => const Ok(null));

      final result = await build(
        _StubPicker(Ok(_Document(name: 'ID.PNG', extension: 'PNG'))),
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
          Ok(_Document(bytes: Uint8List(FileToUpload.maxFileSizeBytes + 1))),
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
        _StubPicker(Ok(_Document(name: 'payload.exe', extension: 'exe'))),
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

    test('a rejected upload does not retain the API sentence', () async {
      final upload = _MockUploadKycDocument();
      when(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: any(named: 'fileName'),
        ),
      ).thenAnswer(
        (_) async => const Err(ExchangeDocumentUploadFailure(_rawReason)),
      );

      final result = await build(
        _StubPicker(Ok(_Document())),
        upload,
      ).execute();

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsDocumentUploadFailure>());
      _expectSanitized(failure);
    });

    test(
      'a credential read refusal becomes a sanitized upload failure',
      () async {
        final upload = _MockUploadKycDocument();
        when(
          () => upload.execute(
            fileBytes: any(named: 'fileBytes'),
            fileName: any(named: 'fileName'),
          ),
        ).thenAnswer((_) async => const Err(ExchangeCredentialReadFailure()));

        final result = await build(
          _StubPicker(Ok(_Document())),
          upload,
        ).execute();

        final failure = (result as Err).failure as ExchangeSettingsFailure;
        expect(failure, isA<ExchangeSettingsDocumentUploadFailure>());
        _expectSanitized(failure);
      },
    );

    test('a picker failure short-circuits without uploading', () async {
      final upload = _MockUploadKycDocument();
      final picker = _StubPicker(
        const Err(FileSystemPickFailure('PlatformException')),
      );

      final result = await build(picker, upload).execute();

      expect((result as Err).failure, isA<ExchangeSettingsUnexpectedFailure>());
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
      ).thenAnswer((_) async => const Ok(null));

      final result = await build(
        _StubPicker(Ok(_Document())),
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
