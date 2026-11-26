import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

export 'ark_transfer_facade.dart'
    show ArkTransferBoardEntry, ArkTransferPaymentEntry;

/// An account selector for a read-only page, never funding authority.
final class ArkAccountEntry {
  final ArkAccountId account;
  const ArkAccountEntry(this.account);
}

/// Explicit Ark entry. General Receive and payment-route preferences are not
/// part of this surface. The captured account survives subsequent UI changes.
final class ArkPaymentEntry {
  final ArkAccountId account;
  final String destination;
  const ArkPaymentEntry(this.account, {this.destination = ''});
}

/// A route selector, not recovery authority. The page reads its own journal.
final class ArkClaimRecoveryEntry {
  final ArkAccountId account;
  final String operationId;
  const ArkClaimRecoveryEntry(this.account, this.operationId);
}

abstract final class ArkNavigation {
  static void open(BuildContext context) => context.push('/ark');
  static void account(BuildContext context, ArkAccountId account) =>
      context.push('/ark/account', extra: ArkAccountEntry(account));
  static void reviewClaimRecovery(
    BuildContext context,
    ArkAccountId account,
    String operationId,
  ) => context.push(
    '/ark/claim-recovery',
    extra: ArkClaimRecoveryEntry(account, operationId),
  );
  static void send(
    BuildContext context,
    ArkAccountId account, {
    String destination = '',
  }) => context.push(
    '/ark/pay',
    extra: ArkPaymentEntry(account, destination: destination),
  );
}
