import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:primitives/primitives.dart';

/// The child provider of the headless task: it provides none.
///
/// A background renewal would have to hand the Ark child's words to the native
/// opener from a process that has no session, so the headless task reads no
/// seed at all. Saved claims rebroadcast bytes that are already signed and
/// never ask for a child; renewal runs in the foreground, where a session
/// exists. Every request here is refused before any storage is touched.
final class DisabledRenewalChildProvider implements ArkChildProviderPort {
  const DisabledRenewalChildProvider();

  static const _refusal = ArkRenewalDisabledFailure();

  @override
  Future<Result<T, ArkWalletFailure>> withChild<T>(
    ArkAccountId account,
    Future<Result<T, ArkWalletFailure>> Function(
      String mnemonic,
      Fingerprint fingerprint,
    )
    action,
  ) async => const Err(_refusal);

  @override
  Future<Result<void, ArkWalletFailure>> admitBatch(
    ArkAccountId account,
  ) async => const Err(_refusal);
}
