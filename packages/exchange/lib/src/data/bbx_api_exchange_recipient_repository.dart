import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

import '../domain/entities/default_wallet.dart';
import '../domain/exchange_failure.dart';

/// Default Bitcoin, Lightning and Liquid payouts for one session.
final class BbxApiExchangeRecipientRepository {
  final bbx.Bbx _api;

  BbxApiExchangeRecipientRepository({required this._api});

  Future<Result<DefaultWallets, ExchangeFailure>> getDefaultWallets() async {
    final result = await _api.recipients.listMyRecipients(
      recipientTypes: WalletAddressType.values.map(_recipientType).toList(),
      isDefault: true,
    );
    switch (result) {
      case Ok(:final value):
        DefaultWallet? bitcoin;
        DefaultWallet? lightning;
        DefaultWallet? liquid;
        for (final recipient in value) {
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
        return Ok(
          DefaultWallets(
            bitcoin: bitcoin,
            lightning: lightning,
            liquid: liquid,
          ),
        );
      case Err(:final failure):
        return Err(_mapFailure(failure));
    }
  }

  Future<Result<DefaultWallet, ExchangeFailure>> saveDefaultWallet({
    required WalletAddressType walletType,
    required String address,
    String? existingRecipientId,
  }) async {
    final result = existingRecipientId != null && existingRecipientId.isNotEmpty
        ? await _api.recipients.updateMyRecipient(
            recipientId: existingRecipientId,
            recipientType: _recipientType(walletType),
            address: address,
            isDefault: true,
          )
        : await _api.recipients.createMyRecipient(
            recipientType: _recipientType(walletType),
            address: address,
            isOwner: true,
            isDefault: true,
          );
    return switch (result) {
      Ok(:final value) => Ok(_toDefaultWallet(value)),
      Err(:final failure) => Err(_mapFailure(failure)),
    };
  }

  Future<Result<void, ExchangeFailure>> deleteDefaultWallet({
    required String recipientId,
    required WalletAddressType walletType,
    required String address,
  }) async {
    final result = await _api.recipients.updateMyRecipient(
      recipientId: recipientId,
      recipientType: _recipientType(walletType),
      address: address,
      isDefault: false,
    );
    return result.map((_) {}).mapErr(_mapFailure);
  }

  static String _recipientType(WalletAddressType type) => switch (type) {
    WalletAddressType.bitcoin => 'OUT_BITCOIN_ADDRESS',
    WalletAddressType.lightning => 'OUT_LIGHTNING_ADDRESS',
    WalletAddressType.liquid => 'OUT_LIQUID_ADDRESS',
  };

  static ExchangeFailure _mapFailure(bbx.BbxFailure failure) =>
      switch (failure) {
        bbx.BbxMissingCredentialFailure() =>
          const ExchangeNotAuthenticatedFailure(),
        bbx.BbxCredentialUnavailableFailure() =>
          const ExchangeApiKeyStorageFailure(),
        bbx.BbxHttpFailure(status: 401) =>
          const ExchangeSessionRejectedFailure(),
        bbx.BbxTimeoutFailure() ||
        bbx.BbxConnectionFailure() => const ExchangeNetworkFailure(),
        _ => ExchangeUnexpectedFailure(
          'Exchange destination request failed: ${_describe(failure)}',
        ),
      };

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
  static Object _describe(bbx.BbxFailure failure) => switch (failure) {
    bbx.BbxRpcFailure(:final code) =>
      'BbxRpcFailure(code: $code)${failure.requestIdLabel}',
    _ => failure.runtimeType.toString(),
  };
}
