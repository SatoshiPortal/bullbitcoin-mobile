import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/recipient_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';

class ExchangeRecipientRepositoryImpl implements ExchangeRecipientRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;

  ExchangeRecipientRepositoryImpl({required this._bullbitcoinApiDatasource});

  @override
  Future<DefaultWallets> getDefaultWallets() async {
    try {
      final recipients = await _bullbitcoinApiDatasource.listMyRecipients(
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
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
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
      final Map<String, dynamic> result;

      if (existingRecipientId != null && existingRecipientId.isNotEmpty) {
        // Update existing recipient
        result = await _bullbitcoinApiDatasource.updateMyRecipient(
          recipientId: existingRecipientId,
          recipientType: walletType.recipientTypeValue,
          address: address,
          isDefault: true,
        );
      } else {
        // Create new recipient
        result = await _bullbitcoinApiDatasource.createMyRecipient(
          recipientType: walletType.recipientTypeValue,
          address: address,
          isOwner: true,
          isDefault: true,
        );
      }

      final model = RecipientModel.fromJson(result);
      return model.toEntity();
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
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
      await _bullbitcoinApiDatasource.updateMyRecipient(
        recipientId: recipientId,
        recipientType: walletType.recipientTypeValue,
        address: address,
        isDefault: false,
      );
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      if (e is ApiKeyException) rethrow;
      throw Exception('Failed to delete default wallet: $e');
    }
  }
}
