import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';

typedef _Next = StepNext<InteracSecurityState, InteracSecurityEffect>;

const _editing = InteracEditing(
  question: 'Pet?',
  answer: 'rex',
  saveAsDefault: true,
);
const _invalid = InteracEditing(
  question: 'Pet?',
  answer: 'New York',
  saveAsDefault: false,
);
final _answered = transitionInteracSecurity(
  _editing,
  const InteracContinuePressed(),
).state;

final _states = <InteracSecurityState>[_editing, _invalid, _answered];

const _events = <InteracSecurityEvent>[
  InteracQuestionTyped('Car?'), // 0
  InteracAnswerTyped('vw'), // 1
  InteracSaveAsDefaultSet(save: false), // 2
  InteracContinuePressed(), // 3
  InteracEditPressed(), // 4
];

final _table = <InteracSecurityState, Map<int, _Next>>{
  _editing: {
    0: const _Next(
      InteracEditing(question: 'Car?', answer: 'rex', saveAsDefault: true),
    ),
    1: const _Next(
      InteracEditing(question: 'Pet?', answer: 'vw', saveAsDefault: true),
    ),
    2: const _Next(
      InteracEditing(question: 'Pet?', answer: 'rex', saveAsDefault: false),
    ),
    3: _Next(_answered),
  },
  _invalid: {
    0: const _Next(
      InteracEditing(
        question: 'Car?',
        answer: 'New York',
        saveAsDefault: false,
      ),
    ),
    1: const _Next(
      InteracEditing(question: 'Pet?', answer: 'vw', saveAsDefault: false),
    ),
    2: const _Next(_invalid),
    3: const _Next(
      InteracEditing(
        question: 'Pet?',
        answer: 'New York',
        saveAsDefault: false,
        problem: InteracAnswerProblem.answerCharacters,
      ),
    ),
  },
  _answered: {4: const _Next(_editing)},
};

void main() {
  test('the table has a row for every state', () {
    expect(_table.keys, _states);
  });

  for (final state in _states) {
    for (final (index, event) in _events.indexed) {
      test('$state + ${event.runtimeType} #$index', () {
        final next = transitionInteracSecurity(state, event);
        final expected = _table[state]![index];
        if (expected == null) {
          expect(identical(next.state, state), isTrue, reason: '$next');
          expect(next.effects, isEmpty);
        } else {
          expect(next, expected);
        }
      });
    }
  }

  test('the answer is what the order sends, with the save choice', () {
    final answered = _answered as InteracAnswered;
    expect(answered.evidence.answer.question, 'Pet?');
    expect(answered.evidence.answer.answer, 'rex');
    expect(answered.evidence.saveAsDefault, isTrue);
  });

  test(
    'starts prefilled from the recipient, saving ticked when it has one',
    () {
      expect(
        interacSecurityStart(
          const InteracSecurityRequired(question: ' Pet? ', answer: 'rex'),
        ),
        const _Next(_editing),
      );
      expect(
        interacSecurityStart(const InteracSecurityRequired()),
        const _Next(
          InteracEditing(question: '', answer: '', saveAsDefault: false),
        ),
      );
    },
  );

  test('an empty answer is refused, never sent', () {
    final next = transitionInteracSecurity(
      interacSecurityStart(const InteracSecurityRequired()).state,
      const InteracContinuePressed(),
    );
    expect(
      next.state,
      const InteracEditing(
        question: '',
        answer: '',
        saveAsDefault: false,
        problem: InteracAnswerProblem.missing,
      ),
    );
  });

  test('every state is reachable', () {
    final reached = <Type>{};
    var frontier = <InteracSecurityState>[
      interacSecurityStart(
        const InteracSecurityRequired(question: 'Pet?', answer: 'rex'),
      ).state,
    ];
    reached.add(frontier.single.runtimeType);
    while (frontier.isNotEmpty) {
      final next = <InteracSecurityState>[];
      for (final state in frontier) {
        for (final event in _events) {
          final target = transitionInteracSecurity(state, event).state;
          if (reached.add(target.runtimeType)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });
}
