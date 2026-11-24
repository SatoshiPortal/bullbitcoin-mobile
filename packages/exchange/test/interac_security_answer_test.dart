import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  final cases = <(String?, String?, InteracAnswerProblem?)>[
    ('Favourite city?', 'Montreal', null),
    ('  Pet?  ', '  rex-2  ', null),
    ('Abc', 'abc', null),
    ('Ça va?', 'Éléonore', null),
    (null, 'Montreal', InteracAnswerProblem.missing),
    ('Favourite city?', '', InteracAnswerProblem.missing),
    ('   ', 'Montreal', InteracAnswerProblem.missing),
    ('Hi', 'Montreal', InteracAnswerProblem.questionLength),
    ('Q' * 41, 'Montreal', InteracAnswerProblem.questionLength),
    ('Favourite city?', 'ab', InteracAnswerProblem.answerLength),
    ('Favourite city?', 'a' * 41, InteracAnswerProblem.answerLength),
    ('Favourite city?', 'New York', InteracAnswerProblem.answerCharacters),
    ('Favourite city?', 'york!', InteracAnswerProblem.answerCharacters),
  ];

  for (final (question, answer, problem) in cases) {
    test('"$question" / "$answer" -> $problem', () {
      expect(InteracSecurityAnswer.check(question, answer), problem);
      final created = InteracSecurityAnswer.create(question, answer);
      if (problem == null) {
        expect(created, isA<Ok<InteracSecurityAnswer, InteracAnswerProblem>>());
      } else {
        expect(
          created,
          isA<Err<InteracSecurityAnswer, InteracAnswerProblem>>().having(
            (err) => err.failure,
            'failure',
            problem,
          ),
        );
      }
    });
  }

  test('the answer is trimmed and never printed', () {
    final created = InteracSecurityAnswer.create(' Pet? ', ' rex ');
    final answer =
        (created as Ok<InteracSecurityAnswer, InteracAnswerProblem>).value;
    expect(answer.question, 'Pet?');
    expect(answer.answer, 'rex');
    expect(answer.toString(), isNot(contains('rex')));
  });

  test('the recipient details use the same rules', () {
    expect(
      InteracSecurityDetails.create(
        recipientId: 'r',
        email: 'a@b.ca',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'New York',
      ),
      isA<Err<InteracSecurityDetails, RecipientsFailure>>(),
    );
    expect(
      InteracSecurityDetails.create(
        recipientId: 'r',
        email: 'a@b.ca',
        securityQuestion: 'Pet?',
        securityAnswer: 'rex',
      ),
      isA<Ok<InteracSecurityDetails, RecipientsFailure>>(),
    );
  });
}
