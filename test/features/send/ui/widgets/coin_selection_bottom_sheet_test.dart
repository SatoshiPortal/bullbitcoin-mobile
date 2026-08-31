import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/ui/widgets/coin_selection_bottom_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes every manual-selection shortfall failure', () {
    expect(
      selectionFailureShowsWarning(
        const SendSelectedCoinsInsufficientFailure(),
      ),
      isTrue,
    );
    expect(
      selectionFailureShowsWarning(const SendSelectedCoinsUnavailableFailure()),
      isTrue,
    );
  });

  test('does not show the selection warning for unrelated failures', () {
    expect(
      selectionFailureShowsWarning(const SendInsufficientBalanceFailure()),
      isTrue,
    );
    expect(
      selectionFailureShowsWarning(const SendUnexpectedFailure()),
      isFalse,
    );
  });
}
