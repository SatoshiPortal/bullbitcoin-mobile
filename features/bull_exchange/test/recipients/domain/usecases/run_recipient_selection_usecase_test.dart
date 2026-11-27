import 'package:bull_exchange/src/recipients/domain/usecases/run_recipient_selection_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../recipient_fixture.dart';

void main() {
  final recipient = recipientFixture('r1', RecipientType.sinpeMovilCrc);

  test('hands the recipient to the hook', () async {
    final handed = <(String, bool)>[];
    final usecase = RunRecipientSelectionUsecase((r, {required isNew}) async {
      handed.add((r.id, isNew));
    });
    expect(
      await usecase.execute(recipient, isNew: true),
      isA<Ok<void, ExchangeRecipientsSelectionFailure>>(),
    );
    expect(handed, [('r1', true)]);
  });

  test('no hook is a selection that worked', () async {
    expect(
      await const RunRecipientSelectionUsecase(null)
          .execute(recipient, isNew: false),
      isA<Ok<void, ExchangeRecipientsSelectionFailure>>(),
    );
  });

  test('a throwing hook is a selection failure without its message', () async {
    final answer = await RunRecipientSelectionUsecase(
      (r, {required isNew}) async => throw StateError('withdraw blew up'),
    ).execute(recipient, isNew: false);
    expect(
      answer,
      isA<Err<void, ExchangeRecipientsSelectionFailure>>().having(
        (e) => e.failure.logMessage,
        'logMessage',
        isNull,
      ),
    );
  });
}
