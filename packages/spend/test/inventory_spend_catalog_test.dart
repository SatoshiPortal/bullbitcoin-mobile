import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:spend/setup.dart';
import 'package:spend/spend.dart';

void main() {
  test(
    'resolves the requested ID through the active inventory each time',
    () async {
      final inventory = _UnavailableInventory();
      final catalog = SpendCatalog.fromInventory(inventory);

      for (var attempt = 0; attempt < 2; attempt++) {
        expect(
          await catalog.resolve('requested'),
          isA<Err<SpendWallet, SpendFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<SpendUnavailableFailure>(),
          ),
        );
      }
      expect(inventory.requestedIds, ['requested', 'requested']);
    },
  );
}

final class _UnavailableInventory implements WalletInventory {
  final requestedIds = <String>[];

  @override
  Future<Result<WalletRegistration, SecretFailure>> readWallet(
    String id,
  ) async {
    requestedIds.add(id);
    return const Err(WalletRegistrationNotFoundFailure());
  }

  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) => throw StateError('Spend must resolve the exact wallet ID');
}
