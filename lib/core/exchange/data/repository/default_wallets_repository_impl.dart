import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/default_wallet_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet_address.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/default_wallets_repository.dart';

class DefaultWalletsRepositoryImpl implements DefaultWalletsRepository {
  final BullbitcoinApiDatasource _apiDatasource;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  DefaultWalletsRepositoryImpl({
    required BullbitcoinApiDatasource apiDatasource,
    required BullbitcoinApiKeyDatasource apiKeyDatasource,
    required bool isTestnet,
  })  : _apiDatasource = apiDatasource,
        _apiKeyDatasource = apiKeyDatasource,
        _isTestnet = isTestnet;

  Future<String> _getApiKey() async {
    final apiKeyModel = await _apiKeyDatasource.get(isTestnet: _isTestnet);

    if (apiKeyModel == null) {
      throw ApiKeyException(
        'API key not found. Please login to your Bull Bitcoin account.',
      );
    }

    if (!apiKeyModel.isActive) {
      throw ApiKeyException(
        'API key is inactive. Please login again to your Bull Bitcoin account.',
      );
    }

    return apiKeyModel.key;
  }

  @override
  Future<DefaultWallets> getDefaultWallets() async {
    try {
      final apiKey = await _getApiKey();

      final walletsJson = await _apiDatasource.listDefaultWallets(
        apiKey: apiKey,
      );

      final models = walletsJson
          .map((json) => DefaultWalletModel.fromJson(json))
          .toList();

      DefaultWalletAddress? bitcoin;
      DefaultWalletAddress? lightning;
      DefaultWalletAddress? liquid;

      for (final model in models) {
        final entity = model.toEntity();
        if (entity == null) continue;

        switch (entity.addressType) {
          case WalletAddressType.bitcoin:
            bitcoin = entity;
          case WalletAddressType.lightning:
            lightning = entity;
          case WalletAddressType.liquid:
            liquid = entity;
        }
      }

      return DefaultWallets(
        bitcoin: bitcoin,
        lightning: lightning,
        liquid: liquid,
      );
    } catch (e) {
      throw Exception('Failed to get default wallets: $e');
    }
  }

  @override
  Future<DefaultWalletAddress> saveDefaultWallet({
    required WalletAddressType addressType,
    required String address,
    String? existingRecipientId,
  }) async {
    try {
      final apiKey = await _getApiKey();
      final recipientType = DefaultWalletModel.recipientTypeFromAddressType(
        addressType,
      );

      Map<String, dynamic> resultJson;

      if (existingRecipientId != null && existingRecipientId.isNotEmpty) {
        // Update existing recipient
        resultJson = await _apiDatasource.updateRecipient(
          apiKey: apiKey,
          recipientId: existingRecipientId,
          address: address,
          isDefault: true,
        );
      } else {
        // Create new recipient
        resultJson = await _apiDatasource.createRecipient(
          apiKey: apiKey,
          recipientType: recipientType,
          address: address,
          isDefault: true,
          isOwner: true,
        );
      }

      final model = DefaultWalletModel.fromJson(resultJson);
      final entity = model.toEntity();

      if (entity == null) {
        throw Exception('Failed to parse saved wallet');
      }

      return entity;
    } catch (e) {
      throw Exception('Failed to save default wallet: $e');
    }
  }

  @override
  Future<bool> deleteDefaultWallet({required String recipientId}) async {
    try {
      final apiKey = await _getApiKey();

      await _apiDatasource.updateRecipient(
        apiKey: apiKey,
        recipientId: recipientId,
        isDefault: false,
      );

      return true;
    } catch (e) {
      throw Exception('Failed to delete default wallet: $e');
    }
  }

  @override
  Future<bool> validateAddress({
    required WalletAddressType addressType,
    required String address,
  }) async {
    // Basic validation - more complex validation can be added later
    if (address.isEmpty) return false;

    switch (addressType) {
      case WalletAddressType.bitcoin:
        // Basic Bitcoin address validation
        return address.startsWith('bc1') ||
            address.startsWith('1') ||
            address.startsWith('3') ||
            address.startsWith('tb1'); // testnet
      case WalletAddressType.lightning:
        // Lightning address format: user@domain
        return address.contains('@') && address.split('@').length == 2;
      case WalletAddressType.liquid:
        // Basic Liquid address validation
        return address.startsWith('ex1') ||
            address.startsWith('lq1') ||
            address.startsWith('VJL') ||
            address.startsWith('tex1'); // testnet
    }
  }
}






