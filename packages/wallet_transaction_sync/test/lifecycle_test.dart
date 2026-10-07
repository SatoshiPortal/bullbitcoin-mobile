import 'package:test/test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

void main() {
  test('source failures expose a typed reason and no exception text', () {
    const failure = SourceFailure(SourceFailureReason.unavailable);
    expect(failure.reason, SourceFailureReason.unavailable);
    expect(failure.safeMessage, isNull);
  });

  test('closed source sessions reject use', () async {
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    late WalletSourceSession session;
    await coordinator.runExclusive(const WalletSourceKey('w', 'c', 'n'), (
      value,
    ) async {
      session = value;
      value.ensureOpen();
    });
    expect(session.isClosed, isTrue);
    expect(session.ensureOpen, throwsStateError);
  });
}
