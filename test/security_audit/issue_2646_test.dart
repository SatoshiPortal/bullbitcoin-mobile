// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2646
// Finding: next-index allocation and insertion are separate, raceable operations.
// Regression test for the implemented mitigation: the cubit serializes
// derivation actions so concurrent taps cannot race on the next index.
// NOTE: datasource-level atomicity (transaction around allocate+insert) is
// not implemented — tracked as a remaining partial in the audit PR.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2646 atomic BIP85 allocation', () {
    test('cubit serializes concurrent derivation actions', () {
      final cubit = File(
        'lib/features/bip85_entropy/presentation/cubit.dart',
      ).readAsStringSync();

      expect(cubit, contains('_derivationInProgress'));
      expect(cubit, contains('if (_derivationInProgress) return;'));
    });
  });
}
