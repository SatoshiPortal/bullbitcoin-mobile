import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

import '../domain/entities/btc_network.dart';
import '../domain/entities/default_wallet.dart';
import '../domain/exchange_failure.dart';
import 'btc_network_wire.dart';
import 'exchange_call_classifier.dart';

/// Default Bitcoin, Lightning and Liquid payouts for one session.
final class BbxApiDefaultWalletsDatasource {
  final bbx.Bbx _api;

  BbxApiDefaultWalletsDatasource({required this._api});

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
  /// [ExchangeWriteOutcomeUnknownFailure]: a new recipient may exist, so the caller re-reads
  /// before saving again (DW-2).
  Future<Result<DefaultWallet, ExchangeWriteFailure>> saveDefaultWallet({
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

  /// Unsets the default flag of [recipientId]. Like a save, an answer lost
  /// after sending is [ExchangeWriteOutcomeUnknownFailure]: re-read before unsetting again.
  Future<Result<void, ExchangeWriteFailure>> deleteDefaultWallet({
    required String recipientId,
    required BtcNetwork walletType,
    required String address,
  }) => exchangeWrite<bbx.MyRecipient, void>(
    'deleteDefaultWallet',
    () => _api.recipients.updateMyRecipient(
      recipientId: recipientId,
      recipientType: BtcNetworkWire.recipientType(walletType),
      address: address,
      isDefault: false,
    ),
    (_) {},
  );

  static ExchangeFailure _mapFailure(bbx.BbxFailure failure) =>
      switch (failure) {
        bbx.BbxMissingCredentialFailure() =>
          const ExchangeNotAuthenticatedFailure(),
        bbx.BbxCredentialUnavailableFailure() =>
          const ExchangeApiKeyStorageFailure(),
        bbx.BbxHttpFailure(status: 401) => const ExchangeSessionRejectedFailure(
          ExchangeSessionRejection.server,
        ),
        bbx.BbxTimeoutFailure() ||
        bbx.BbxConnectionFailure() => const ExchangeNetworkFailure(),
        bbx.BbxHttpFailure() ||
        bbx.BbxRpcFailure() ||
        bbx.BbxOrderLimitFailure() ||
        bbx.BbxConfidentialSepaInactiveFailure() ||
        bbx.BbxBadCertificateFailure() ||
        bbx.BbxRequestCancelledFailure() ||
        bbx.BbxTransformTimeoutFailure() ||
        bbx.BbxTransportFailure() ||
        bbx.BbxOutcomeUnknownFailure() ||
        bbx.BbxResponseFormatFailure() => ExchangeUnexpectedFailure(
          'Exchange destination request failed: $failure',
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
}
