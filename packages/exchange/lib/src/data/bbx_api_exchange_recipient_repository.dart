import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

import '../domain/entities/btc_network.dart';
import '../domain/entities/default_wallet.dart';
import '../domain/exchange_call_result.dart';
import '../domain/exchange_failure.dart';
import 'btc_network_wire.dart';
import 'exchange_call_classifier.dart';

/// Default Bitcoin, Lightning and Liquid payouts for one session.
final class BbxApiExchangeRecipientRepository {
  final bbx.Bbx _api;

  BbxApiExchangeRecipientRepository({required this._api});

  Future<Result<DefaultWallets, ExchangeFailure>> getDefaultWallets() async {
    final result = await _api.recipients.listMyRecipients(
      recipientTypes: BtcNetworkWire.recipientTypes,
      isDefault: true,
    );
    switch (result) {
      case Ok(:final value):
        DefaultWallet? bitcoin;
        DefaultWallet? lightning;
        DefaultWallet? liquid;
        for (final recipient in value) {
          // A rail this build doesn't know is not read as another one.
          final network = switch (BtcNetworkWire.parseRecipientType(
            recipient.recipientType,
          )) {
            KnownBtcNetwork(:final network) => network,
            UnknownBtcNetwork() => null,
          };
          if (network == null) continue;
          final wallet = _toDefaultWallet(recipient, network);
          switch (network) {
            case BtcNetwork.bitcoin:
              bitcoin = wallet;
            case BtcNetwork.lightning:
              lightning = wallet;
            case BtcNetwork.liquid:
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

  /// A save that may have reached the server without a readable answer is
  /// [WriteOutcomeUnknown]: a new recipient may exist, so the caller re-reads
  /// before saving again (DW-2).
  Future<ExchangeWrite<DefaultWallet>> saveDefaultWallet({
    required BtcNetwork walletType,
    required String address,
    String? existingRecipientId,
  }) => exchangeWrite<bbx.MyRecipient, DefaultWallet>(
    'saveDefaultWallet',
    () => existingRecipientId != null && existingRecipientId.isNotEmpty
        ? _api.recipients.updateMyRecipient(
            recipientId: existingRecipientId,
            recipientType: BtcNetworkWire.recipientType(walletType),
            address: address,
            isDefault: true,
          )
        : _api.recipients.createMyRecipient(
            recipientType: BtcNetworkWire.recipientType(walletType),
            address: address,
            isOwner: true,
            isDefault: true,
          ),
    (recipient) => _toDefaultWallet(recipient, walletType),
  );

  Future<Result<void, ExchangeFailure>> deleteDefaultWallet({
    required String recipientId,
    required BtcNetwork walletType,
    required String address,
  }) async {
    final result = await _api.recipients.updateMyRecipient(
      recipientId: recipientId,
      recipientType: BtcNetworkWire.recipientType(walletType),
      address: address,
      isDefault: false,
    );
    return result.map((_) {}).mapErr(_mapFailure);
  }

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

  static DefaultWallet _toDefaultWallet(
    bbx.MyRecipient recipient,
    BtcNetwork network,
  ) => DefaultWallet(
    recipientId: recipient.recipientId,
    walletType: network,
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
