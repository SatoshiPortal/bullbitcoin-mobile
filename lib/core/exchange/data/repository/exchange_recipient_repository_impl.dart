import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/recipient_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';

class ExchangeRecipientRepositoryImpl implements ExchangeRecipientRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;
  final bool _isTestnet;

  ExchangeRecipientRepositoryImpl({
    required BullbitcoinApiDatasource bullbitcoinApiDatasource,
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
    required bool isTestnet,
  }) : _bullbitcoinApiDatasource = bullbitcoinApiDatasource,
       _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource,
       _isTestnet = isTestnet;

  Future<String> _getApiKey() async {
    final apiKey = await _bullbitcoinApiKeyDatasource.get(isTestnet: _isTestnet);
    if (apiKey == null || !apiKey.isActive) {
      throw ApiKeyException(
        'API key not found. Please login to your Bull Bitcoin account.',
      );
    }
    return apiKey.key;
  }

  @override
  Future<DefaultWallets> getDefaultWallets() async {
    try {
      final apiKey = await _getApiKey();

      final recipients = await _bullbitcoinApiDatasource.listMyRecipients(
        apiKey: apiKey,
        recipientTypes: [
          'OUT_BITCOIN_ADDRESS',
          'OUT_LIGHTNING_ADDRESS',
          'OUT_LIQUID_ADDRESS',
        ],
        isDefault: true,
      );

      DefaultWallet? bitcoin;
      DefaultWallet? lightning;
      DefaultWallet? liquid;

      for (final json in recipients) {
        final model = RecipientModel.fromJson(json);
        final wallet = model.toEntity();

        switch (wallet.walletType) {
          case WalletAddressType.bitcoin:
            bitcoin = wallet;
          case WalletAddressType.lightning:
            lightning = wallet;
          case WalletAddressType.liquid:
            liquid = wallet;
        }
      }

      return DefaultWallets(
        bitcoin: bitcoin,
        lightning: lightning,
        liquid: liquid,
      );
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      throw Exception('Failed to get default wallets: $e');
    }
  }

  @override
  Future<DefaultWallet> saveDefaultWallet({
    required WalletAddressType walletType,
    required String address,
    String? existingRecipientId,
  }) async {
    try {
      final apiKey = await _getApiKey();

      final Map<String, dynamic> result;

      if (existingRecipientId != null && existingRecipientId.isNotEmpty) {
        // Update existing recipient
        result = await _bullbitcoinApiDatasource.updateMyRecipient(
          apiKey: apiKey,
          recipientId: existingRecipientId,
          address: address,
          isDefault: true,
        );
      } else {
        // Create new recipient
        result = await _bullbitcoinApiDatasource.createMyRecipient(
          apiKey: apiKey,
          recipientType: walletType.recipientTypeValue,
          address: address,
          isOwner: true,
          isDefault: true,
        );
      }

      final model = RecipientModel.fromJson(result);
      return model.toEntity();
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      throw Exception('Failed to save default wallet: $e');
    }
  }

  @override
  Future<void> deleteDefaultWallet({
    required String recipientId,
  }) async {
    try {
      final apiKey = await _getApiKey();

      await _bullbitcoinApiDatasource.updateMyRecipient(
        apiKey: apiKey,
        recipientId: recipientId,
        isDefault: false,
      );
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      throw Exception('Failed to delete default wallet: $e');
    }
  }
}

