part of 'dlc_wallet_auth_cubit.dart';

enum DlcWalletAuthStatus {
  /// Not yet determined — need to check persisted preference.
  unknown,

  /// User has not yet decided whether to use DLC.
  notDecided,

  /// User explicitly opted out of DLC.
  optedOut,

  /// Currently registering the wallet.
  registering,

  /// Wallet successfully registered and token available.
  registered,

  /// Registration attempt failed.
  failed,
}

@freezed
abstract class DlcWalletAuthState with _$DlcWalletAuthState {
  const factory DlcWalletAuthState({
    @Default(DlcWalletAuthStatus.unknown) DlcWalletAuthStatus status,
    String? walletId,
    String? error,
  }) = _DlcWalletAuthState;

  const DlcWalletAuthState._();

  bool get isRegistered => status == DlcWalletAuthStatus.registered;
  bool get isRegistering => status == DlcWalletAuthStatus.registering;
  bool get isOptedOut => status == DlcWalletAuthStatus.optedOut;
  bool get needsDecision => status == DlcWalletAuthStatus.notDecided;
}
