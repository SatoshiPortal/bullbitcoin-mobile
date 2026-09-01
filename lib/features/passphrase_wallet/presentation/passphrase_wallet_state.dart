import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:flutter/foundation.dart' show listEquals;

enum PassphraseWalletLoadStatus { initial, loading, success, failure }

enum PassphraseWalletBalanceStatus { idle, syncing, success, failure }

final class PassphraseWalletCardState {
  final PassphraseWalletRecord wallet;
  final PassphraseWalletBalanceStatus balanceStatus;
  final PassphraseWalletBalance? balance;

  const PassphraseWalletCardState({
    required this.wallet,
    this.balanceStatus = PassphraseWalletBalanceStatus.idle,
    this.balance,
  });

  PassphraseWalletCardState copyWith({
    PassphraseWalletRecord? wallet,
    PassphraseWalletBalanceStatus? balanceStatus,
    PassphraseWalletBalance? balance,
    bool clearBalance = false,
  }) => PassphraseWalletCardState(
    wallet: wallet ?? this.wallet,
    balanceStatus: balanceStatus ?? this.balanceStatus,
    balance: clearBalance ? null : balance ?? this.balance,
  );

  @override
  bool operator ==(Object other) =>
      other is PassphraseWalletCardState &&
      identical(other.wallet, wallet) &&
      other.balanceStatus == balanceStatus &&
      other.balance == balance;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(wallet), balanceStatus, balance);
}

/// Everything the Passphrase page shows, including which wallet is loaded.
///
/// One owner, one immutable value: the Cubit reads loaded-versus-locked from
/// the wallet feature and writes it here, and the widgets read it from here.
/// Nothing on the page asks a repository or a session what is loaded while it
/// builds, which is how a loaded wallet used to end up under a card still
/// saying Locked (spec F20).
///
/// Value equality is part of that guarantee: recomputing the same page state
/// produces no transition at all, so "one event, one transition" holds even
/// when two sources report the same change.
final class PassphraseWalletState {
  final PassphraseWalletLoadStatus status;
  final List<PassphraseWalletCardState> wallets;

  /// The passphrase wallet holding the private session, if it is one of
  /// [wallets]. Null means every card on this page is locked.
  final String? loadedWalletId;

  /// Whether the passphrase input and its keyboard are open.
  final bool isEntering;

  /// Whether an entry attempt is in flight, from submission until it opens a
  /// wallet, fails, or is discarded.
  final bool isSubmitting;
  final PassphraseWalletFailure? failure;

  const PassphraseWalletState({
    this.status = PassphraseWalletLoadStatus.initial,
    this.wallets = const [],
    this.loadedWalletId,
    this.isEntering = false,
    this.isSubmitting = false,
    this.failure,
  });

  bool isLoaded(String walletId) => loadedWalletId == walletId;

  bool get hasLoadedWallet => loadedWalletId != null;

  PassphraseWalletState copyWith({
    PassphraseWalletLoadStatus? status,
    List<PassphraseWalletCardState>? wallets,
    String? loadedWalletId,
    bool clearLoadedWalletId = false,
    bool? isEntering,
    bool? isSubmitting,
    PassphraseWalletFailure? failure,
    bool clearFailure = false,
  }) => PassphraseWalletState(
    status: status ?? this.status,
    wallets: wallets ?? this.wallets,
    loadedWalletId: clearLoadedWalletId
        ? null
        : loadedWalletId ?? this.loadedWalletId,
    isEntering: isEntering ?? this.isEntering,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  bool operator ==(Object other) =>
      other is PassphraseWalletState &&
      other.status == status &&
      listEquals(other.wallets, wallets) &&
      other.loadedWalletId == loadedWalletId &&
      other.isEntering == isEntering &&
      other.isSubmitting == isSubmitting &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(wallets),
    loadedWalletId,
    isEntering,
    isSubmitting,
    failure,
  );
}
