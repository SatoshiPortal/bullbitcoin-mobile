import 'package:exchange/exchange.dart';
import 'package:test/test.dart';

Recipient _recipient(RecipientDetails details, {String id = 'r-1'}) =>
    Recipient.create(
      recipientId: id,
      userId: 'u-1',
      userNbr: 1,
      isArchived: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      details: details,
    );

final _interac = InteracEmailCadDetails.create(
  email: 'a@b.ca',
  name: 'Ann',
  isOwner: true,
  securityQuestion: 'Pet?',
  securityAnswer: 'rex',
);

final _sepa = SepaEurDetails.create(
  iban: 'FR76',
  isCorporate: false,
  firstname: 'Ana',
  lastname: 'Silva',
  isOwner: true,
);

void main() {
  group('requirements per rail', () {
    for (final purpose in PayoutPurpose.values) {
      test('Interac asks for the security answer on $purpose', () {
        expect(_interac.onRail.requirements(purpose), [
          const InteracSecurityRequired(question: 'Pet?', answer: 'rex'),
        ]);
      });

      test(
        'Confidential SEPA needs the virtual IBAN and payee on $purpose',
        () {
          expect(_sepa.asConfidential().onRail.requirements(purpose), [
            const VirtualIbanRequired(),
            const VirtualPayeeRequired(alreadyActive: false),
          ]);
          final active = SepaEurDetails.create(
            iban: 'FR76',
            isCorporate: false,
            firstname: 'Ana',
            lastname: 'Silva',
            virtualPayeeStatus: SepaVirtualPayeeStatus.active,
          ).asConfidential();
          expect(active.onRail.requirements(purpose), [
            const VirtualIbanRequired(),
            const VirtualPayeeRequired(alreadyActive: true),
          ]);
        },
      );

      test('regular SEPA needs nothing on $purpose', () {
        expect(_sepa.onRail.requirements(purpose), isEmpty);
      });
    }

    test('a rail without extra steps needs nothing', () {
      expect(
        SinpeMovilCrcDetails.create(phoneNumber: '8888').onRail
            .requirements(PayoutPurpose.pay),
        isEmpty,
      );
    });
  });

  group('filter', () {
    final own = RecipientFilter(
      rails: [PayoutRails.interacEmail, PayoutRails.sepa],
      owner: RecipientOwnership.own,
    );

    test('admits a recipient of a listed rail and the right owner', () {
      final chosen = own.choose(_recipient(_interac));
      expect(chosen, isNotNull);
      expect(chosen!.rail, PayoutRails.interacEmail);
    });

    test('refuses a rail the flow does not list', () {
      expect(own.choose(_recipient(_sepa.asConfidential())), isNull);
      expect(
        own.choose(_recipient(SinpeIbanCrcDetails.create(iban: 'CR'))),
        isNull,
      );
    });

    test('refuses another owner, and an unknown owner when one is asked', () {
      final theirs = InteracEmailCadDetails.create(
        email: 'a@b.ca',
        name: 'Ann',
        isOwner: false,
      );
      final unknown = InteracEmailCadDetails.create(email: 'a@b.ca', name: 'A');
      expect(own.choose(_recipient(theirs)), isNull);
      expect(own.choose(_recipient(unknown)), isNull);
      final any = RecipientFilter(rails: [PayoutRails.interacEmail]);
      expect(any.choose(_recipient(theirs)), isNotNull);
      expect(any.choose(_recipient(unknown)), isNotNull);
    });
  });

  test('Confidential SEPA falls back to the same account on SEPA', () {
    final filter = RecipientFilter(rails: [PayoutRails.confidentialSepa]);
    final chosen = filter.choose(_recipient(_sepa.asConfidential()))!;
    final fallback = chosen.fallback!;
    expect(fallback.rail, PayoutRails.sepa);
    expect(fallback.recipient.recipientId, 'r-1');
    expect(fallback.requirements(PayoutPurpose.withdraw), isEmpty);
    expect(fallback.fallback, isNull);
  });
}
