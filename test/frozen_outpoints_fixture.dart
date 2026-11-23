import 'package:primitives/primitives.dart' show Outpoint, Ok, Result;
import 'package:coins/coins.dart';
import 'package:mocktail/mocktail.dart';

/// A deliberately empty frozen store for tests of other broadcast policies.
final class EmptyFrozenOutpoints extends Fake implements Coins {
  @override
  Future<Result<List<Outpoint>, CoinsFailure>> frozenOutpoints() async =>
      const Ok([]);
}
