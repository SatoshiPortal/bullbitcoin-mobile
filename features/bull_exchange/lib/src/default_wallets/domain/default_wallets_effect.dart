import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

@immutable
sealed class DefaultWalletsEffect {
  const DefaultWalletsEffect();
}

final class FetchDefaultWallets extends DefaultWalletsEffect {
  final ExchangeSession session;
  final int attempt;

  const FetchDefaultWallets(this.session, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FetchDefaultWallets &&
      other.session == session &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FetchDefaultWallets, session, attempt);
}

final class CheckWalletAddress extends DefaultWalletsEffect {
  final BtcNetwork network;
  final int attempt;
  final String text;

  const CheckWalletAddress(this.network, this.attempt, this.text);

  @override
  bool operator ==(Object other) =>
      other is CheckWalletAddress &&
      other.network == network &&
      other.attempt == attempt &&
      other.text == text;

  @override
  int get hashCode => Object.hash(CheckWalletAddress, network, attempt, text);
}

final class SaveDefaultWallet extends DefaultWalletsEffect {
  final ExchangeSession session;
  final BtcNetwork network;
  final int attempt;
  final String address;
  final String? existingRecipientId;

  const SaveDefaultWallet(
    this.session,
    this.network,
    this.attempt,
    this.address, {
    this.existingRecipientId,
  });

  @override
  bool operator ==(Object other) =>
      other is SaveDefaultWallet &&
      other.session == session &&
      other.network == network &&
      other.attempt == attempt &&
      other.address == address &&
      other.existingRecipientId == existingRecipientId;

  @override
  int get hashCode => Object.hash(
    SaveDefaultWallet,
    session,
    network,
    attempt,
    address,
    existingRecipientId,
  );
}

final class UnsetDefaultWallet extends DefaultWalletsEffect {
  final ExchangeSession session;
  final BtcNetwork network;
  final int attempt;
  final String recipientId;
  final String address;

  const UnsetDefaultWallet(
    this.session,
    this.network,
    this.attempt, {
    required this.recipientId,
    required this.address,
  });

  @override
  bool operator ==(Object other) =>
      other is UnsetDefaultWallet &&
      other.session == session &&
      other.network == network &&
      other.attempt == attempt &&
      other.recipientId == recipientId &&
      other.address == address;

  @override
  int get hashCode => Object.hash(
    UnsetDefaultWallet,
    session,
    network,
    attempt,
    recipientId,
    address,
  );
}

/// Reconciles the journal, then reads the wallets again.
final class VerifyDefaultWallets extends DefaultWalletsEffect {
  final ExchangeSession session;
  final BtcNetwork network;
  final int attempt;

  const VerifyDefaultWallets(this.session, this.network, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is VerifyDefaultWallets &&
      other.session == session &&
      other.network == network &&
      other.attempt == attempt;

  @override
  int get hashCode =>
      Object.hash(VerifyDefaultWallets, session, network, attempt);
}
