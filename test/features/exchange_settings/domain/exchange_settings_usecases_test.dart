import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_stats_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/upload_kyc_document_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/document_picker_port.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/delete_exchange_default_wallet_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_default_wallets_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_settings_account_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_statistics_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/save_exchange_default_wallet_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/upload_exchange_document_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

/// The kind of text the exchange API and the SDKs put in an exception: a
/// sentence plus an identifier that must never be rendered.
const _rawReason =
    'ExchangeApiException[ERR_KYC_403]: recipient bc1qexamplerecipient rejected';

class _MockGetOrderStats extends Mock implements GetOrderStatsUsecase {}

class _MockGetDefaultWallets extends Mock implements GetDefaultWalletsUsecase {}

class _MockSaveDefaultWallet extends Mock implements SaveDefaultWalletUsecase {}

class _MockDeleteDefaultWallet extends Mock
    implements DeleteDefaultWalletUsecase {}

class _MockGetUserSummary extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockUploadKycDocument extends Mock implements UploadKycDocumentUsecase {}

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
    registerFallbackValue(WalletAddressType.bitcoin);
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

  group('GetExchangeDefaultWalletsUsecase', () {
    test('a throwing core use-case becomes a sanitized failure', () async {
      final core = _MockGetDefaultWallets();
      when(core.execute).thenThrow(StateError(_rawReason));

      final result = await GetExchangeDefaultWalletsUsecase(
        getDefaultWalletsUsecase: core,
      ).execute();

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsDefaultWalletsUnavailableFailure>());
      _expectSanitized(failure);
    });
  });

  group('SaveExchangeDefaultWalletUsecase', () {
    // The cubit calls this synchronously to avoid flashing a spinner; execute()
    // applies the same rule, so the two must agree.
    test('validate() and execute() agree on what is empty', () async {
      final core = _MockSaveDefaultWallet();
      final usecase = SaveExchangeDefaultWalletUsecase(
        saveDefaultWalletUsecase: core,
      );

      for (final blank in ['', '   ', '\t']) {
        expect(
          SaveExchangeDefaultWalletUsecase.validate(blank),
          isA<ExchangeSettingsWalletAddressEmptyFailure>(),
        );
        expect(
          (await usecase.execute(
                    walletType: WalletAddressType.bitcoin,
                    address: blank,
                  )
                  as Err)
              .failure,
          isA<ExchangeSettingsWalletAddressEmptyFailure>(),
        );
      }

      expect(
        SaveExchangeDefaultWalletUsecase.validate('bc1qexamplerecipient'),
        isNull,
      );
    });

    test('an empty address never reaches the exchange', () async {
      final core = _MockSaveDefaultWallet();

      for (final blank in ['', '   ']) {
        final result = await SaveExchangeDefaultWalletUsecase(
          saveDefaultWalletUsecase: core,
        ).execute(walletType: WalletAddressType.bitcoin, address: blank);

        expect(
          (result as Err).failure,
          isA<ExchangeSettingsWalletAddressEmptyFailure>(),
        );
      }

      verifyNever(
        () => core.execute(
          walletType: any(named: 'walletType'),
          address: any(named: 'address'),
          existingRecipientId: any(named: 'existingRecipientId'),
        ),
      );
    });

    test('a throwing core use-case becomes a sanitized failure', () async {
      final core = _MockSaveDefaultWallet();
      when(
        () => core.execute(
          walletType: any(named: 'walletType'),
          address: any(named: 'address'),
          existingRecipientId: any(named: 'existingRecipientId'),
        ),
      ).thenThrow(Exception(_rawReason));

      final result =
          await SaveExchangeDefaultWalletUsecase(
            saveDefaultWalletUsecase: core,
          ).execute(
            walletType: WalletAddressType.bitcoin,
            address: 'bc1qexamplerecipient',
          );

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsWalletSaveFailure>());
      _expectSanitized(failure);
    });
  });

  group('DeleteExchangeDefaultWalletUsecase', () {
    test('a throwing core use-case becomes a sanitized failure', () async {
      final core = _MockDeleteDefaultWallet();
      when(
        () => core.execute(
          recipientId: any(named: 'recipientId'),
          walletType: any(named: 'walletType'),
          address: any(named: 'address'),
        ),
      ).thenThrow(Exception(_rawReason));

      final result =
          await DeleteExchangeDefaultWalletUsecase(
            deleteDefaultWalletUsecase: core,
          ).execute(
            recipientId: 'rec-1',
            walletType: WalletAddressType.bitcoin,
            address: 'bc1qexamplerecipient',
          );

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsWalletDeleteFailure>());
      _expectSanitized(failure);
    });
  });

  group('GetExchangeSettingsAccountUsecase', () {
    test('a throwing core use-case becomes a sanitized failure', () async {
      final core = _MockGetUserSummary();
      when(core.execute).thenThrow(Exception(_rawReason));

      final result = await GetExchangeSettingsAccountUsecase(
        getExchangeUserSummaryUsecase: core,
      ).execute();

      final failure = (result as Err).failure as ExchangeSettingsFailure;
      expect(failure, isA<ExchangeSettingsAccountUnavailableFailure>());
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
