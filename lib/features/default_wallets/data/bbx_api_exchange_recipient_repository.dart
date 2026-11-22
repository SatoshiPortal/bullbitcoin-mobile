import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

/// [ExchangeRecipientRepository] on the `bbx_api` package: the default
/// Bitcoin, Lightning and Liquid payout addresses of one environment.
class BbxApiExchangeRecipientRepository implements ExchangeRecipientRepository {
  final bbx.Bbx _api;

  BbxApiExchangeRecipientRepository({required this._api});

  @override
  Future<DefaultWallets> getDefaultWallets() async {
    final result = await _api.recipients.listMyRecipients(
      recipientTypes: [
        'OUT_BITCOIN_ADDRESS',
        'OUT_LIGHTNING_ADDRESS',
        'OUT_LIQUID_ADDRESS',
      ],
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
        return DefaultWallets(
          bitcoin: bitcoin,
          lightning: lightning,
          liquid: liquid,
        );
      case Err(:final failure):
        _throwFailure(failure, 'Failed to get default wallets');
    }
  }

  @override
  Future<DefaultWallet> saveDefaultWallet({
    required WalletAddressType walletType,
    required String address,
    String? existingRecipientId,
  }) async {
    final result = existingRecipientId != null && existingRecipientId.isNotEmpty
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
    return switch (result) {
      Ok(:final value) => _toDefaultWallet(value),
      Err(:final failure) => _throwFailure(
        failure,
        'Failed to save default wallet',
      ),
    };
  }

  @override
  Future<void> deleteDefaultWallet({
    required String recipientId,
    required WalletAddressType walletType,
    required String address,
  }) async {
    final result = await _api.recipients.updateMyRecipient(
      recipientId: recipientId,
      recipientType: walletType.recipientTypeValue,
      address: address,
      isDefault: false,
    );
    switch (result) {
      case Ok():
        return;
      case Err(:final failure):
        _throwFailure(failure, 'Failed to delete default wallet');
    }
  }

  static Never _throwFailure(bbx.BbxFailure failure, String context) {
    switch (failure) {
      case bbx.BbxMissingCredentialFailure():
        throw ApiKeyNotFoundException();
      case bbx.BbxCredentialUnavailableFailure():
        throw const ExchangeCredentialUnavailableException();
      default:
        throw Exception('$context: ${_describe(failure)}');
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
  static Object _describe(bbx.BbxFailure failure) => switch (failure) {
    bbx.BbxRpcFailure(:final code) => 'BbxRpcFailure(code: $code)',
    _ => failure.runtimeType.toString(),
  };
}
