import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;

/// [ExchangeRecipientRepository] on the `bbx_api` package: the default
/// Bitcoin, Lightning and Liquid payout addresses of one environment.
class BbxApiExchangeRecipientRepository implements ExchangeRecipientRepository {
  final bbx.BbxApiClient _api;

  BbxApiExchangeRecipientRepository({required this._api});

  @override
  Future<DefaultWallets> getDefaultWallets() async {
    try {
      final recipients = await _api.recipients.listMyRecipients(
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
      for (final recipient in recipients) {
        final wallet = _toDefaultWallet(recipient);
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
      throw Exception('Failed to get default wallets: ${_describe(e)}');
    }
  }

  @override
  Future<DefaultWallet> saveDefaultWallet({
    required WalletAddressType walletType,
    required String address,
    String? existingRecipientId,
  }) async {
    try {
      final recipient =
          existingRecipientId != null && existingRecipientId.isNotEmpty
          ? await _api.recipients.updateMyRecipient(
              recipientId: existingRecipientId,
              recipientType: walletType.recipientTypeValue,
              address: address,
              isDefault: true,
            )
          : await _api.recipients.createMyRecipient(
              recipientType: walletType.recipientTypeValue,
              address: address,
              isOwner: true,
              isDefault: true,
            );
      return _toDefaultWallet(recipient);
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to save default wallet: ${_describe(e)}');
    }
  }

  @override
  Future<void> deleteDefaultWallet({
    required String recipientId,
    required WalletAddressType walletType,
    required String address,
  }) async {
    try {
      await _api.recipients.updateMyRecipient(
        recipientId: recipientId,
        recipientType: walletType.recipientTypeValue,
        address: address,
        isDefault: false,
      );
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to delete default wallet: ${_describe(e)}');
    }
  }

  /// An unknown recipient type is read as a Bitcoin address.
  static DefaultWallet _toDefaultWallet(bbx.MyRecipient recipient) =>
      DefaultWallet(
        recipientId: recipient.recipientId,
        walletType: switch (recipient.recipientType) {
          'OUT_LIGHTNING_ADDRESS' => WalletAddressType.lightning,
          'OUT_LIQUID_ADDRESS' => WalletAddressType.liquid,
          _ => WalletAddressType.bitcoin,
        },
        address:
            recipient.address ??
            recipient.bitcoinAddress ??
            recipient.lightningAddress ??
            recipient.liquidAddress ??
            '',
        isDefault: recipient.isDefault ?? false,
      );

  /// A JSON-RPC error message can quote the request, so only its code is
  /// kept.
  static Object _describe(Object e) => switch (e) {
    bbx.BbxApiRpcException(:final code) => 'BbxApiRpcException(code: $code)',
    _ => e,
  };
}
