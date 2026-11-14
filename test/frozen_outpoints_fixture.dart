import 'package:primitives/primitives.dart' show Outpoint;
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:mocktail/mocktail.dart';

/// A deliberately empty frozen store for tests of other broadcast policies.
final class EmptyFrozenOutpoints extends Fake implements WalletUtxoRepository {
  @override
  Future<List<Outpoint>> getAllFrozenOutpoints() async => [];
}
