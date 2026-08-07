import 'package:bb_mobile/core/exchange/data/mappers/user_summary_mapper.dart';
import 'package:bb_mobile/core/exchange/data/models/user_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The payjoin-with-the-exchange gate is server-side: the backend publishes
/// `payjoinReceiveEnabled` on the user summary and every payjoin surface (buy
/// toggle, sell toggle) hangs off it. These tests pin the one property that
/// matters for funds safety: the gate must be CLOSED unless the backend
/// explicitly opens it, so a response that predates the field — or an account
/// outside the pilot — never offers a payjoin the exchange would reject.
void main() {
  Map<String, dynamic> summaryJson({bool? payjoinReceiveEnabled}) => {
    'userNumber': 1,
    'groups': <String>[],
    'profile': {'firstName': 'Ada', 'lastName': 'Lovelace'},
    'email': 'ada@example.com',
    'balances': <Map<String, dynamic>>[],
    'dca': {'isActive': false},
    'autoBuy': {'isActive': false, 'addresses': <String, dynamic>{}},
    'payjoinReceiveEnabled': ?payjoinReceiveEnabled,
  };

  group('payjoinReceiveEnabled gate', () {
    test('is false when the backend omits the field entirely', () {
      final model = UserSummaryModel.fromJson(summaryJson());

      expect(model.payjoinReceiveEnabled, isFalse);
      expect(
        UserSummaryMapper.fromModelToEntity(model).payjoinReceiveEnabled,
        isFalse,
        reason: 'a response without the field must not enable payjoin',
      );
    });

    test('is false when the backend sends it explicitly disabled', () {
      final model = UserSummaryModel.fromJson(
        summaryJson(payjoinReceiveEnabled: false),
      );

      expect(
        UserSummaryMapper.fromModelToEntity(model).payjoinReceiveEnabled,
        isFalse,
      );
    });

    test('is true only when the backend enables it', () {
      final model = UserSummaryModel.fromJson(
        summaryJson(payjoinReceiveEnabled: true),
      );

      expect(
        UserSummaryMapper.fromModelToEntity(model).payjoinReceiveEnabled,
        isTrue,
      );
    });

    test('is independent of the pilot group appearing in groups', () {
      // The backend derives the flag from the pilot group, but that grouping is
      // a backend-internal detail: the app must not re-derive the gate from
      // `groups`, or it would diverge the day the backend changes how it
      // decides. A summary carrying the group but not the flag stays closed.
      final model = UserSummaryModel.fromJson({
        ...summaryJson(),
        'groups': <String>['FF_PAYJOIN_RECEIVE_PILOT'],
      });

      expect(
        UserSummaryMapper.fromModelToEntity(model).payjoinReceiveEnabled,
        isFalse,
      );
    });
  });
}
