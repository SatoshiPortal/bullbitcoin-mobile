import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart'
    show
        SyncClosedFailure,
        SyncFailure,
        SyncNotFoundFailure,
        SyncStorageFailure,
        WalletKey;

/// The wallet a Payjoin original transaction is broadcast from, or why
/// nothing was sent.
///
/// An inventory relocked, or whose session changed, refuses access: the
/// broadcast was never attempted, so it reads as a closed session and the
/// payjoin resumes once unlocked, not as an unknown outcome.
Result<WalletKey, SyncFailure> payjoinBroadcastWallet(
  Result<WalletRegistration, SecretFailure> read,
) => switch (read) {
  Ok(:final value) => Ok(WalletKey(id: value.id, network: value.network)),
  Err(failure: WalletRegistrationNotFoundFailure()) => const Err(
    SyncNotFoundFailure(),
  ),
  Err(failure: UseSecretFailure()) => const Err(SyncClosedFailure()),
  Err() => const Err(SyncStorageFailure()),
};
