import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/models/scoped_api_key_model.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;

class ExchangeApiKeyRepositoryImpl implements ExchangeApiKeyRepository {
  static const _credentialImportError =
      'Unable to import Bull Bitcoin credentials';
  static const _credentialDeletionError =
      'Unable to delete Bull Bitcoin credentials';

  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;

  ExchangeApiKeyRepositoryImpl({required this._bullbitcoinApiKeyDatasource});

  @override
  Future<void> saveApiKey(
    Map<String, dynamic> apiKeyResponseData, {
    required bool isTestnet,
  }) async {
    // The ordinary Bull Bitcoin key is required for login. The scoped
    // SELL_TO_FIAT_BALANCE key is optional: ordinary login must never depend on
    // scoped issuance, so its absence, nullness, or malformation is tolerated.
    final broadApiKeyData = apiKeyResponseData['apiKey'];
    if (broadApiKeyData is! Map) {
      throw Exception(_credentialImportError);
    }

    late final ExchangeApiKeyModel apiKeyModel;
    try {
      apiKeyModel = ExchangeApiKeyModel.fromJson(
        Map<String, dynamic>.from(broadApiKeyData),
      );
    } catch (_) {
      throw Exception(_credentialImportError);
    }

    // Resolve any previously stored scoped credential and, if it belongs to a
    // different Bull Bitcoin user, remove it before completing the switch so a
    // foreign scoped key can never survive an account change.
    final existingScoped = await _bullbitcoinApiKeyDatasource
        .getSellToFiatBalanceApiKey(isTestnet: isTestnet);
    final isAccountSwitch =
        existingScoped != null && existingScoped.userId != apiKeyModel.userId;
    if (isAccountSwitch) {
      await _bullbitcoinApiKeyDatasource.deleteSellToFiatBalanceApiKey(
        isTestnet: isTestnet,
      );
    }

    // Persist the ordinary key (this is the login / account switch itself).
    try {
      await _bullbitcoinApiKeyDatasource.store(
        apiKeyModel,
        isTestnet: isTestnet,
      );
    } catch (_) {
      throw Exception(_credentialImportError);
    }

    // Handle the optional scoped key on a best-effort basis: a failure here must
    // not fail the login.
    await _importScopedApiKey(
      apiKeyResponseData['sellToFiatBalanceApiKey'],
      userId: apiKeyModel.userId,
      isTestnet: isTestnet,
    );
  }

  Future<void> _importScopedApiKey(
    Object? scopedValue, {
    required String userId,
    required bool isTestnet,
  }) async {
    // Field absent or null: preserve any existing same-user scoped key.
    if (scopedValue == null) return;
    // Anything non-string is treated as malformed: preserve, never store.
    if (scopedValue is! String) return;

    final candidate = ScopedApiKeyModel(
      userId: userId,
      key: scopedValue.trim(),
    );
    // Malformed value: do not store it; preserve a same-user existing key and
    // never log the supplied value.
    if (!candidate.isWellFormed) return;

    try {
      await _bullbitcoinApiKeyDatasource.storeSellToFiatBalanceApiKey(
        candidate,
        isTestnet: isTestnet,
      );
    } catch (_) {
      // Scoped storage is best-effort; fiat conversion is simply unavailable
      // until the next successful import. Never surface or log the value.
      log.warning('Unable to store scoped Bull Bitcoin credential');
    }
  }

  @override
  Future<bool> hasApiKey({required bool isTestnet}) async {
    final key = await _bullbitcoinApiKeyDatasource.get(isTestnet: isTestnet);
    return key != null;
  }

  @override
  Future<void> deleteApiKey({required bool isTestnet}) async {
    var failed = false;
    try {
      await _bullbitcoinApiKeyDatasource.delete(isTestnet: isTestnet);
    } catch (_) {
      failed = true;
    }

    try {
      await _bullbitcoinApiKeyDatasource.deleteSellToFiatBalanceApiKey(
        isTestnet: isTestnet,
      );
    } catch (_) {
      failed = true;
    }

    if (failed) {
      throw Exception(_credentialDeletionError);
    }
  }
}
