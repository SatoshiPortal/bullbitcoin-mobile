import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:swaps/swaps.dart';

class _Boltz extends Mock implements BoltzSwaps {}

void main() {
  test('reports reachability through the injected Boltz capability', () async {
    final boltz = _Boltz();
    final check = SwapHomeServerCheck(boltz);
    when(boltz.checkServer).thenAnswer((_) async => const Ok(null));
    expect(await check.reachable(), isTrue);
    when(boltz.checkServer)
        .thenAnswer((_) async => const Err(SwapsUnexpectedFailure()));
    expect(await check.reachable(), isFalse);
    verify(boltz.checkServer).called(2);
  });
}
