import 'dart:async';
import 'dart:typed_data';

import 'package:bull_exchange/src/settings/domain/entities/file_upload.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:file_system/file_system.dart';
import 'package:bull_exchange/src/settings/domain/entities/account_info.dart';
import 'package:bull_exchange/src/settings/domain/entities/exchange_preferences.dart';
import 'package:bull_exchange/src/settings/domain/exchange_settings_failure.dart';
import 'package:bull_exchange/src/settings/domain/entities/secure_file_upload.dart';
import 'package:bull_exchange/src/settings/domain/usecases/get_account_info_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/get_exchange_preferences_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/get_exchange_statistics_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/get_secure_file_upload_status_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/pick_exchange_document_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/update_exchange_preferences_usecase.dart';
import 'package:bull_exchange/src/settings/domain/entities/exchange_document_to_upload.dart';
import 'package:bull_exchange/src/settings/domain/usecases/upload_exchange_document_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

/// The kind of text the exchange API and the SDKs put in an exception: a
/// sentence plus an identifier that must never be rendered.
const _rawReason =
    'ExchangeApiException[ERR_KYC_403]: recipient bc1qexamplerecipient rejected';

abstract interface class _SummaryReader {
  Future<Result<UserSummary, ExchangeFailure>> execute();
}

class _MockGetUserSummary extends Mock implements _SummaryReader {}

const _signedIn = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'signed-in',
);
const _earlier = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 0,
  sessionId: 'earlier',
);

Exchange _withSummary(_SummaryReader summary) => exchangeForTesting(
  access: fixedAccessForTesting(const ExchangeAccessSignedIn(_signedIn)),
  getUserSummary: (_) => summary.execute(),
);

abstract interface class _Upload {
  Future<Result<void, ExchangeFailure>> execute({
    required List<int> fileBytes,
    required String fileName,
  });
}

class _MockUploadKycDocument extends Mock implements _Upload {}

abstract interface class _SavePreferences {
  Future<Result<void, ExchangeFailure>> savePreferences(
    ExchangeSession session,
    ExchangePreferencesPatch patch,
  );
}

class _MockExchangeFacade extends Mock implements _SavePreferences {}

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
      when(core.execute).thenAnswer(
        (_) async => Ok(_summary(groups: ['KYC_CANADA_LIGHT_VERIFICATION'])),
      );

      final result = await GetAccountInfoUsecase(exchange: _withSummary(core))
          .execute();

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
        (_) async => Ok(
          _summary(
            groups: ['KYC_LIMITED_VERIFICATION', 'KYC_IDENTITY_VERIFIED'],
          ),
        ),
      );

      final result = await GetAccountInfoUsecase(exchange: _withSummary(core))
          .execute();

      expect(
        (result as Ok<AccountInfo, ExchangeSettingsFailure>)
            .value
            .verificationLevel,
        VerificationLevel.identityVerified,
      );
    });

    test('no KYC group means not verified', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenAnswer((_) async => Ok(_summary()));

      final result = await GetAccountInfoUsecase(exchange: _withSummary(core))
          .execute();

      expect(
        (result as Ok<AccountInfo, ExchangeSettingsFailure>)
            .value
            .verificationLevel,
        VerificationLevel.notVerified,
      );
    });

    test('an Exchange failure becomes a sanitized account failure', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenAnswer(
        (_) async => const Err(ExchangeAccountUnavailableFailure(_rawReason)),
      );

      final result = await GetAccountInfoUsecase(exchange: _withSummary(core))
          .execute();

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsAccountUnavailableFailure>());
      _expectSanitized(failure);
    });

    for (final failure in const <ExchangeFailure>[
      ExchangeNotAuthenticatedFailure(),
      ExchangeSessionRejectedFailure(),
    ]) {
      test('${failure.runtimeType} is signed out, not a retryable error '
          '(SET-3)', () async {
        final core = _MockGetUserSummary();
        when(core.execute).thenAnswer((_) async => Err(failure));

        final result = await GetAccountInfoUsecase(exchange: _withSummary(core))
            .execute();

        expect(
          (result as Err).failure,
          isA<ExchangeSettingsNotAuthenticatedFailure>(),
        );
      });
    }
  });

  group('GetExchangePreferencesUsecase', () {
    test('maps the user summary to the preferences', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenAnswer((_) async => Ok(_summary()));

      final result = await GetExchangePreferencesUsecase(
        exchange: _withSummary(core),
      ).execute(_signedIn);

      final preferences =
          (result as Ok<ExchangePreferences, ExchangeSettingsFailure>).value;
      expect(preferences.language, 'FR');
      expect(preferences.currency, 'EUR');
      expect(preferences.emailNotificationsEnabled, isFalse);
    });

    test(
      'an Exchange failure becomes a sanitized preferences failure',
      () async {
        final core = _MockGetUserSummary();
        when(core.execute).thenAnswer(
          (_) async => const Err(ExchangeAccountUnavailableFailure(_rawReason)),
        );

        final result = await GetExchangePreferencesUsecase(
          exchange: _withSummary(core),
        ).execute(_signedIn);

        final failure = (result as Err).failure as ExchangeSettingsFailure;
        expect(failure, isA<ExchangeSettingsAccountUnavailableFailure>());
        _expectSanitized(failure);
      },
    );

    for (final failure in const <ExchangeFailure>[
      ExchangeNotAuthenticatedFailure(),
      ExchangeSessionRejectedFailure(),
    ]) {
      test('${failure.runtimeType} is signed out, not a retryable error '
          '(SET-3)', () async {
        final core = _MockGetUserSummary();
        when(core.execute).thenAnswer((_) async => Err(failure));

        final result = await GetExchangePreferencesUsecase(
          exchange: _withSummary(core),
        ).execute(_signedIn);

        expect(
          (result as Err).failure,
          isA<ExchangeSettingsNotAuthenticatedFailure>(),
        );
      });
    }
  });

  group('preference and upload status reads with another session', () {
    test('no session reads nothing', () async {
      final core = _MockGetUserSummary();
      expect(
        (await GetExchangePreferencesUsecase(
          exchange: _withSummary(core),
        ).execute(null) as Err).failure,
        isA<ExchangeSettingsNotAuthenticatedFailure>(),
      );
      expect(
        (await GetSecureFileUploadStatusUsecase(
          exchange: _withSummary(core),
        ).execute(null) as Err).failure,
        isA<ExchangeSettingsUploadStatusUnavailableFailure>(),
      );
      verifyNever(core.execute);
    });

    test('a session that is no longer current reads nothing', () async {
      final core = _MockGetUserSummary();
      expect(
        (await GetExchangePreferencesUsecase(
          exchange: _withSummary(core),
        ).execute(_earlier) as Err).failure,
        isA<ExchangeSettingsAccountUnavailableFailure>(),
      );
      expect(
        (await GetSecureFileUploadStatusUsecase(
          exchange: _withSummary(core),
        ).execute(_earlier) as Err).failure,
        isA<ExchangeSettingsUploadStatusUnavailableFailure>(),
      );
      verifyNever(core.execute);
    });
  });

  group('UpdateExchangePreferencesUsecase', () {
    const loaded = ExchangePreferences(
      language: 'EN',
      currency: 'CAD',
      emailNotificationsEnabled: true,
    );

    setUpAll(() {
      registerFallbackValue(const ExchangePreferencesPatch());
      registerFallbackValue(
        const ExchangeSession(
          environment: ExchangeEnvironment.mainnet,
          epoch: 0,
          sessionId: 'fallback',
        ),
      );
    });

    void stubSave(_MockExchangeFacade facade, Result<void, ExchangeFailure> r) {
      when(() => facade.savePreferences(any(), any()))
          .thenAnswer((_) async => r);
    }

    const session = ExchangeSession(
      environment: ExchangeEnvironment.mainnet,
      epoch: 1,
      sessionId: 'prefs',
    );

    Future<Result<void, ExchangeSettingsFailure>> save(
      _MockExchangeFacade facade,
      ExchangePreferences edited,
    ) async => switch (await UpdateExchangePreferencesUsecase(
      save: facade.savePreferences,
      writeGate: ExchangeWriteGate(),
    ).execute(session, loaded: loaded, edited: edited)) {
      GateAdmitted(:final result) => result,
      GateRefused(:final refusal) => fail('gate refused: $refusal'),
    };

    test('a save while another financial write runs is never sent', () async {
      final facade = _MockExchangeFacade();
      stubSave(facade, const Ok(null));
      final gate = ExchangeWriteGate();
      final release = Completer<String>();
      final running = gate.run(
        session,
        FinancialWriteKind.orderConfirm,
        () => release.future,
      );

      final write =
          await UpdateExchangePreferencesUsecase(
            save: facade.savePreferences,
            writeGate: gate,
          ).execute(
            session,
            loaded: loaded,
            edited: loaded.copyWith(language: 'FR'),
          );

      expect(
        write,
        isA<GateRefused<Result<void, ExchangeSettingsFailure>>>().having(
          (w) => w.refusal,
          'refusal',
          isA<WriteGateBusy>(),
        ),
      );
      verifyNever(() => facade.savePreferences(any(), any()));
      release.complete('done');
      await running;
    });

    test('without a session nothing is sent', () async {
      final facade = _MockExchangeFacade();
      final write =
          await UpdateExchangePreferencesUsecase(
            save: facade.savePreferences,
            writeGate: ExchangeWriteGate(),
          ).execute(
            null,
            loaded: loaded,
            edited: loaded.copyWith(language: 'FR'),
          );

      expect(
        (write as GateAdmitted<Result<void, ExchangeSettingsFailure>>).result,
        isA<Err<void, ExchangeSettingsFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeSettingsNotAuthenticatedFailure>(),
        ),
      );
      verifyNever(() => facade.savePreferences(any(), any()));
    });

    for (final (name, edited, patch) in [
      ('nothing edited', loaded, const ExchangePreferencesPatch()),
      (
        'the language only',
        loaded.copyWith(language: 'FR'),
        const ExchangePreferencesPatch(language: 'FR'),
      ),
      (
        'the currency only',
        loaded.copyWith(currency: 'EUR'),
        const ExchangePreferencesPatch(currency: 'EUR'),
      ),
      (
        'the email notifications only',
        loaded.copyWith(emailNotificationsEnabled: false),
        const ExchangePreferencesPatch(emailNotificationsEnabled: false),
      ),
      (
        'everything',
        const ExchangePreferences(
          language: 'FR',
          currency: 'EUR',
          emailNotificationsEnabled: false,
        ),
        const ExchangePreferencesPatch(
          language: 'FR',
          currency: 'EUR',
          emailNotificationsEnabled: false,
        ),
      ),
    ]) {
      test('$name sends only that (B17, INT-17)', () async {
        final facade = _MockExchangeFacade();
        stubSave(facade, const Ok(null));

        expect(
          await save(facade, edited),
          isA<Ok<void, ExchangeSettingsFailure>>(),
        );
        verify(() => facade.savePreferences(session, patch)).called(1);
      });
    }

    for (final (failure, expected) in [
      (const ExchangeNetworkFailure('offline'), ExchangeSettingsNetworkFailure),
      (
        const ExchangeNotAuthenticatedFailure('expired'),
        ExchangeSettingsNotAuthenticatedFailure,
      ),
      (
        const ExchangePreferencesSaveFailure('rejected'),
        ExchangeSettingsPreferencesSaveFailure,
      ),
    ]) {
      test('${failure.runtimeType} becomes $expected', () async {
        final facade = _MockExchangeFacade();
        stubSave(facade, Err(failure));

        final result = await save(facade, loaded.copyWith(language: 'FR'));

        expect((result as Err).failure.runtimeType, expected);
      });
    }
  });

  group('GetSecureFileUploadStatusUsecase', () {
    test('maps the user summary to the upload status', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenAnswer(
        (_) async => const Ok(
          UserSummary(
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
        ),
      );

      final result = await GetSecureFileUploadStatusUsecase(
        exchange: _withSummary(core),
      ).execute(_signedIn);

      final upload =
          (result as Ok<SecureFileUpload, ExchangeSettingsFailure>).value;
      expect(upload.userId, 'u-42');
      expect(upload.status, KycDocumentStatus.underReview);
    });

    test(
      'an Exchange failure becomes a sanitized upload status failure',
      () async {
        final core = _MockGetUserSummary();
        when(core.execute).thenAnswer(
          (_) async => const Err(ExchangeAccountUnavailableFailure(_rawReason)),
        );

        final result = await GetSecureFileUploadStatusUsecase(
          exchange: _withSummary(core),
        ).execute(_signedIn);

        final failure = (result as Err).failure as ExchangeSettingsFailure;
        expect(failure, isA<ExchangeSettingsUploadStatusUnavailableFailure>());
        _expectSanitized(failure);
      },
    );
  });

  group('PickExchangeDocumentUsecase', () {
    PickExchangeDocumentUsecase build(FileSystem picker) =>
        PickExchangeDocumentUsecase(fileSystem: picker);

    test('a dismissed picker is a cancellation, not a failure', () async {
      final result = await build(_StubPicker(const Ok(null))).execute();

      expect((result as Ok).value, isNull);
    });

    test('an empty file is rejected', () async {
      final result = await build(_StubPicker(Ok(_Document(bytes: const []))))
          .execute();

      expect(
        (result as Err).failure,
        isA<ExchangeSettingsDocumentEmptyFailure>(),
      );
    });

    test('a file the picker could not read is unreadable, not empty', () async {
      final result = await build(_StubPicker(Ok(_Document(bytes: null))))
          .execute();

      expect(
        (result as Err).failure,
        isA<ExchangeSettingsDocumentUnreadableFailure>(),
        reason: 'no bytes means unreadable; an empty list means empty',
      );
    });

    test('an uppercase extension is accepted', () async {
      final result = await build(
        _StubPicker(Ok(_Document(name: 'ID.PNG', extension: 'PNG'))),
      ).execute();

      expect(
        (result as Ok).value,
        isA<ExchangeDocumentToUpload>(),
        reason: 'the domain rule must not depend on the adapter lowercasing',
      );
    });

    test('an oversized file is rejected', () async {
      final result = await build(
        _StubPicker(
          Ok(_Document(bytes: Uint8List(FileToUpload.maxFileSizeBytes + 1))),
        ),
      ).execute();

      expect(
        (result as Err).failure,
        isA<ExchangeSettingsDocumentTooLargeFailure>(),
      );
    });

    test('a disallowed extension is rejected', () async {
      final result = await build(
        _StubPicker(Ok(_Document(name: 'payload.exe', extension: 'exe'))),
      ).execute();

      expect(
        (result as Err).failure,
        isA<ExchangeSettingsDocumentTypeNotAllowedFailure>(),
      );
    });

    test('a picker failure is an unexpected failure', () async {
      final result = await build(
        _StubPicker(const Err(FileSystemPickFailure('PlatformException'))),
      ).execute();

      expect((result as Err).failure, isA<ExchangeSettingsUnexpectedFailure>());
    });

    test('the standardized filename is used when a userId is known', () async {
      final result = await build(_StubPicker(Ok(_Document())))
          .execute(userId: 'u-42');

      expect(
        ((result as Ok).value as ExchangeDocumentToUpload).fileName,
        'doc-u-42-ID',
      );
    });
  });

  group('UploadExchangeDocumentUsecase', () {
    const document = ExchangeDocumentToUpload(
      bytes: [1, 2],
      fileName: 'doc-u-42-ID',
    );

    UploadExchangeDocumentUsecase build(_Upload upload) =>
        UploadExchangeDocumentUsecase(
          exchange: exchangeForTesting(uploadKycDocument: upload.execute),
        );

    test('uploads the document under its name', () async {
      final upload = _MockUploadKycDocument();
      when(
        () => upload.execute(
          fileBytes: any(named: 'fileBytes'),
          fileName: any(named: 'fileName'),
        ),
      ).thenAnswer((_) async => const Ok(null));

      final result = await build(upload).execute(document);

      expect(result, isA<Ok<void, ExchangeSettingsFailure>>());
      verify(() => upload.execute(fileBytes: [1, 2], fileName: 'doc-u-42-ID'))
          .called(1);
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

      final result = await build(upload).execute(document);

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

        final result = await build(upload).execute(document);

        final failure = (result as Err).failure as ExchangeSettingsFailure;
        expect(failure, isA<ExchangeSettingsDocumentUploadFailure>());
        _expectSanitized(failure);
      },
    );
  });
}
