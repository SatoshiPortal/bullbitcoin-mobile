import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/repository/bbx_api_exchange_kyc_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockKycRepo extends Mock implements bbx.KYCRepo {}

class _MockApiKeyDatasource extends Mock
    implements BullbitcoinApiKeyDatasource {}

class _FakeApiKey extends Fake implements ExchangeApiKeyModel {
  _FakeApiKey({this.isActive = true});

  @override
  final bool isActive;
}

class _FakePayload extends Fake implements bbx.UploadKycDocsPayload {}

void main() {
  setUpAll(() => registerFallbackValue(_FakePayload()));

  late _MockKycRepo kyc;
  late _MockApiKeyDatasource apiKeys;
  late BbxApiExchangeKycRepository repository;

  setUp(() {
    kyc = _MockKycRepo();
    final api = _MockBbxApi();
    when(() => api.kyc).thenReturn(kyc);
    apiKeys = _MockApiKeyDatasource();
    repository = BbxApiExchangeKycRepository(
      api: BbxApiDatasource(api),
      apiKeyDatasource: apiKeys,
      isTestnet: false,
    );
    when(
      () => apiKeys.get(isTestnet: false),
    ).thenAnswer((_) async => _FakeApiKey());
  });

  Future<dynamic> upload() => repository.uploadSecureIdDocument(
    fileBytes: const [1, 2, 3],
    fileName: 'doc-1-ID',
  );

  test('uploads a secure ID document', () async {
    when(
      () => kyc.uploadDocumentFile(any()),
    ).thenAnswer((_) async => const bbx.ApiResult<void>.success(data: null));

    final result = await upload();

    expect(result.isSuccess, isTrue);
    final payload =
        verify(() => kyc.uploadDocumentFile(captureAny())).captured.single
            as bbx.UploadKycDocsPayload;
    expect(payload.docType, bbx.DocTypeCode.id);
    expect(payload.source, bbx.SourceDetail.secureUpload);
    expect(payload.fileName, 'doc-1-ID');
    expect(payload.bytes, [1, 2, 3]);
  });

  test('a rejected upload is a failed result without the message', () async {
    when(() => kyc.uploadDocumentFile(any())).thenAnswer(
      (_) async => bbx.ApiResult.apiFailure(
        error: const bbx.ApiError(
          serverMessage: 'server detail',
          httpStatus: 400,
        ),
      ),
    );

    final result = await upload();

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, isNot(contains('server detail')));
  });

  test('no active key throws the API key exception', () async {
    when(
      () => apiKeys.get(isTestnet: false),
    ).thenAnswer((_) async => _FakeApiKey(isActive: false));

    await expectLater(upload(), throwsA(isA<ApiKeyException>()));
  });
}

class _MockBbxApi extends Mock implements bbx.BbxApi {}
