import 'package:sentry_flutter/sentry_flutter.dart';

/// Filters and anonymizes a Sentry event before dispatch.
///
/// Invariant — non-migration events require user consent:
/// - If the event carries the scope tag `category=migration` (set by
///   [MigrationReporter]), the event always passes. This is how migration
///   errors and transitions bypass the user's general error-reporting
///   consent.
/// - Otherwise, the event passes only when [userConsent] is true.
/// - Every passing exception event is anonymized uniformly — `e.value` is
///   stripped — so we never leak txids, addresses, or seed-derived strings.
///
/// Extracted from `beforeSend` so the invariant can be unit-tested in
/// isolation. Do not weaken without updating the wizard and settings
/// disclosure copy.
SentryEvent? filterSentryEvent(
  SentryEvent event, {
  required bool userConsent,
}) {
  final isMigration = event.tags?['category'] == 'migration';
  if (!isMigration && !userConsent) return null;
  final exceptions = event.exceptions;
  if (exceptions != null && exceptions.isNotEmpty) {
    event.exceptions = exceptions.map((e) {
      e.value = null;
      return e;
    }).toList();
  }
  return event;
}
