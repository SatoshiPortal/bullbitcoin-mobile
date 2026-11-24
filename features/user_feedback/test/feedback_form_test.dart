import 'package:flutter_test/flutter_test.dart';
import 'package:user_feedback/src/feedback_form.dart';

void main() {
  group('FeedbackForm.parse', () {
    test('accepts https', () {
      expect(FeedbackForm.parse('https://feedback.example.com/'), isNotNull);
    });

    test('accepts http only on the local machine', () {
      expect(FeedbackForm.parse('http://localhost:8787/'), isNotNull);
      expect(FeedbackForm.parse('http://127.0.0.1:8787/'), isNotNull);
      expect(FeedbackForm.parse('http://feedback.example.com/'), isNull);
    });

    test(
      'rejects an empty or malformed value, which turns the feature off',
      () {
        expect(FeedbackForm.parse(''), isNull);
        expect(FeedbackForm.parse('feedback.example.com'), isNull);
        expect(FeedbackForm.parse('javascript:alert(1)'), isNull);
      },
    );
  });

  test('the form address carries the context and keeps its own query', () {
    final form = FeedbackForm.parse('https://feedback.example.com/?kind=bug');
    if (form == null) fail('expected a form');

    final uri = form.uriFor(
      const FeedbackContext(
        platform: 'ios',
        dark: true,
        appVersion: '6.14.0+100',
        osVersion: '',
        screen: 'send',
      ),
    );

    expect(uri.queryParameters, {
      'kind': 'bug',
      'source': 'app',
      'theme': 'dark',
      'platform': 'ios',
      'app_version': '6.14.0+100',
      'screen': 'send',
    });
  });

  test('navigation stays on the form site', () {
    final form = FeedbackForm.parse('https://feedback.example.com/');
    if (form == null) fail('expected a form');

    expect(form.owns(Uri.parse('https://feedback.example.com/thanks')), isTrue);
    expect(form.owns(Uri.parse('https://evil.example.com/')), isFalse);
    expect(form.owns(Uri.parse('http://feedback.example.com/')), isFalse);
  });
}
