import 'package:bb_mobile/features/exchange_access/domain/exchange_access.dart';

/// Versioned, non-secret representation of the installation-local choices.
class ExchangeAccessModel {
  static Map<bool, ExchangeAccess> decode(Object? json) {
    if (json is! Map<String, dynamic> || json['version'] != 1) {
      throw const FormatException('Invalid exchange access version');
    }
    final result = <bool, ExchangeAccess>{};
    for (final entry in {false: 'mainnet', true: 'testnet'}.entries) {
      final value = json[entry.value];
      if (value == null) continue;
      if (value is! Map<String, dynamic> ||
          value['choice'] is! String ||
          value['transition'] is! String ||
          value['revision'] is! int ||
          (value['revision'] as int) < 0 ||
          value['lastKnownAuthenticated'] is! bool) {
        throw const FormatException('Invalid exchange access entry');
      }
      ExchangeAccessChoice? choice;
      ExchangeAccessTransition? transition;
      for (final candidate in ExchangeAccessChoice.values) {
        if (candidate.name == value['choice']) choice = candidate;
      }
      for (final candidate in ExchangeAccessTransition.values) {
        if (candidate.name == value['transition']) transition = candidate;
      }
      if (choice == null || transition == null) {
        throw const FormatException('Invalid exchange access enum');
      }
      result[entry.key] = ExchangeAccess(
        choice: choice,
        transition: transition,
        revision: value['revision'] as int,
        lastKnownAuthenticated: value['lastKnownAuthenticated'] as bool,
      );
    }
    return result;
  }

  static Map<String, Object> encode(Map<bool, ExchangeAccess> values) {
    final data = <String, Object>{'version': 1};
    for (final entry in values.entries) {
      data[entry.key ? 'testnet' : 'mainnet'] = {
        'choice': entry.value.choice.name,
        'transition': entry.value.transition.name,
        'revision': entry.value.revision,
        'lastKnownAuthenticated': entry.value.lastKnownAuthenticated,
      };
    }
    return data;
  }
}
