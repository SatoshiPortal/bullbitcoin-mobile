import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';

enum ExchangeSessionStatus {
  resolving,
  anonymous,
  authenticated,
  expired,
  unavailable,
  networkUnavailable,
}

/// Non-secret session facts; credential contents remain inside the repository.
class ExchangeSession {
  ExchangeSession(this._keys);

  final ExchangeApiKeyRepository _keys;
  final _changes = StreamController<ExchangeSessionStatus>.broadcast(
    sync: true,
  );
  ExchangeSessionStatus _current = ExchangeSessionStatus.resolving;
  int _generation = 0;

  ExchangeSessionStatus get current => _current;
  Stream<ExchangeSessionStatus> watch() => _changes.stream;

  void publish(ExchangeSessionStatus fact) {
    _generation++;
    _publish(fact);
  }

  void _publish(ExchangeSessionStatus fact) {
    _current = fact;
    _changes.add(fact);
  }

  Future<ExchangeSessionStatus> resolve({required bool isTestnet}) async {
    final generation = ++_generation;
    _publish(ExchangeSessionStatus.resolving);
    final result = await _keys.readActiveApiKey(isTestnet: isTestnet);
    if (generation != _generation) return _current;
    final fact = switch (result) {
      Ok(value: final key) =>
        key == null
            ? ExchangeSessionStatus.anonymous
            : ExchangeSessionStatus.authenticated,
      Err() => ExchangeSessionStatus.unavailable,
    };
    _publish(fact);
    return fact;
  }

  void invalidate() => _generation++;
}
