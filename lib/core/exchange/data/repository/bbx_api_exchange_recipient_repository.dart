import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/mappers/bbx_api_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;

/// [ExchangeRecipientRepository] on the shared `bbx_api` client.
class BbxApiExchangeRecipientRepository implements ExchangeRecipientRepository {
  final BbxApiDatasource _api;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  BbxApiExchangeRecipientRepository({
    required this._api,
    required this._apiKeyDatasource,
    required this._isTestnet,
  });

  @override
  Future<DefaultWallets> getDefaultWallets() async {
    try {
      await _requireApiKey();
      // ignore: deprecated_member_use
      final recipients = (await _api.recipients.listMyRecipients(
        bbx.ListRequest(
          payload: bbx.RecipientsPayload(
            filters: bbx.ListMyRecipientsFilters(
              recipientTypes: [
                for (final type in WalletAddressType.values)
                  BbxApiMapper.recipientType(type),
              ],
              isDefault: true,
              recipientTypesKey: bbx.RecipientTypesFilterKey.plural,
            ),
          ),
        ),
      )).unwrap().items;

      DefaultWallet? bitcoin;
      DefaultWallet? lightning;
      DefaultWallet? liquid;
      for (final recipient in recipients) {
        final wallet = BbxApiMapper.defaultWallet(recipient);
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
      await _requireApiKey();
      final recipientType = BbxApiMapper.recipientType(walletType);
      final result =
          existingRecipientId != null && existingRecipientId.isNotEmpty
          ? await _api.recipients.updateMyRecipientPartial(
              bbx.UpdateMyRecipientPartialPayload.defaultWallet(
                recipientId: existingRecipientId,
                recipientType: recipientType,
                address: address,
                isDefault: true,
              ),
            )
          : switch (bbx.CreateMyRecipientPayload.defaultWallet(
              recipientType: recipientType,
              address: address,
            )) {
              null => throw StateError('$recipientType is not a wallet type'),
              // ignore: deprecated_member_use
              final payload => await _api.recipients.createMyRecipient(payload),
            };
      return BbxApiMapper.defaultWallet(result.unwrap());
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      throw Exception('Failed to save default wallet: $e');
    }
  }

  @override
  Future<void> deleteDefaultWallet({
    required String recipientId,
    required WalletAddressType walletType,
    required String address,
  }) async {
    try {
      await _requireApiKey();
      (await _api.recipients.updateMyRecipientPartial(
        bbx.UpdateMyRecipientPartialPayload.defaultWallet(
          recipientId: recipientId,
          recipientType: BbxApiMapper.recipientType(walletType),
          address: address,
          isDefault: false,
        ),
      )).unwrap();
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      throw Exception('Failed to delete default wallet: $e');
    }
  }

  Future<void> _requireApiKey() async {
    final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
    if (apiKey == null || !apiKey.isActive) {
      throw ApiKeyException(
        'API key not found. Please login to your Bull Bitcoin account.',
      );
    }
  }
}
