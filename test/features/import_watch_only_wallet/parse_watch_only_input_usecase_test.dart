import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ParseWatchOnlyInputUsecase usecase;

  setUp(() => usecase = ParseWatchOnlyInputUsecase());

  group('ParseWatchOnlyInputUsecase', () {
    test(
      'maps unparseable input to InvalidFormatFailure without leaking '
      'the raw parser error',
      () async {
        final result = await usecase.execute(
          'this is definitely not a descriptor or an extended public key',
        );

        expect(
          result,
          isA<Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>(),
        );
        final failure =
            (result as Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>)
                .failure;
        expect(failure, isA<InvalidFormatFailure>());
        expect(failure.logMessage, isNull);
      },
    );
  });
}
