import 'package:bb_mobile/core/utils/sentry_event_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('filterSentryEvent', () {
    test('drops non-migration event when userConsent=false', () {
      final event = SentryEvent();
      expect(filterSentryEvent(event, userConsent: false), isNull);
    });

    test('keeps non-migration event when userConsent=true', () {
      final event = SentryEvent();
      expect(
        filterSentryEvent(event, userConsent: true),
        same(event),
      );
    });

    test('keeps migration-tagged event when userConsent=false', () {
      final event = SentryEvent(tags: const {'category': 'migration'});
      expect(
        filterSentryEvent(event, userConsent: false),
        same(event),
      );
    });

    test('keeps migration-tagged event when userConsent=true', () {
      final event = SentryEvent(tags: const {'category': 'migration'});
      expect(
        filterSentryEvent(event, userConsent: true),
        same(event),
      );
    });

    test('anonymizes exception value on passing events', () {
      final event = SentryEvent(
        tags: const {'category': 'migration'},
        exceptions: [
          SentryException(type: 'FooError', value: 'secret-value'),
        ],
      );
      final result = filterSentryEvent(event, userConsent: true);
      expect(result, isNotNull);
      expect(result!.exceptions, hasLength(1));
      expect(result.exceptions!.first.value, isNull);
      expect(result.exceptions!.first.type, 'FooError');
    });

    test('non-migration event with consent also has exception anonymized', () {
      final event = SentryEvent(
        exceptions: [
          SentryException(type: 'BarError', value: 'user-email@foo'),
        ],
      );
      final result = filterSentryEvent(event, userConsent: true);
      expect(result, isNotNull);
      expect(result!.exceptions!.first.value, isNull);
    });

    test('other tags do not accidentally flag as migration', () {
      final event = SentryEvent(tags: const {'category': 'user_action'});
      expect(
        filterSentryEvent(event, userConsent: false),
        isNull,
      );
    });

    test('passes event with empty exceptions list unchanged', () {
      final event = SentryEvent(
        tags: const {'category': 'migration'},
        exceptions: [],
      );
      final result = filterSentryEvent(event, userConsent: true);
      expect(result, same(event));
      expect(result!.exceptions, isEmpty);
    });
  });
}
