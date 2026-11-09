import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
export 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;

/// Shared broadcast entry point. Local Bitcoin callers must supply the captured
/// wallet identity. Accepted local-record failures retain a live spend barrier.
final class SendFacade {
  final Future<String> Function(
    String, {
    required String walletId,
    required bool isPsbt,
    required Network network,
  })
  _bitcoin;
  final Future<String> Function(String) _liquid;

  const SendFacade({required this._bitcoin, required this._liquid});

  Future<String> bitcoin(
    String transaction, {
    required String walletId,
    required bool isPsbt,
    required Network network,
  }) => _bitcoin(
    transaction,
    walletId: walletId,
    isPsbt: isPsbt,
    network: network,
  );
  Future<String> liquid(String transaction) => _liquid(transaction);
}
