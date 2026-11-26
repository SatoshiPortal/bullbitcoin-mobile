import 'package:wallet_import/src/domain/watch_only/parse_watch_only_input_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ParseWatchOnlyInputUsecase usecase;

  setUp(() => usecase = ParseWatchOnlyInputUsecase());

  group('ParseWatchOnlyInputUsecase', () {
    test('maps unparseable input to InvalidFormatFailure without leaking '
        'the raw parser error', () async {
      final result = await usecase.execute(
        'this is definitely not a descriptor or an extended public key',
        environment: NetworkEnv.mainnet,
      );

      expect(result, isA<Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>());
      final failure =
          (result as Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>)
              .failure;
      expect(failure, isA<InvalidFormatFailure>());
      expect(failure.logMessage, isNull);
    });
  });
}
