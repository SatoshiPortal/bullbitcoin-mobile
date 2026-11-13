import 'dart:convert';

import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/exchange_access/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange_access/data/exchange_access_model.dart';
import 'package:bb_mobile/features/exchange_access/domain/exchange_access_failure.dart';
import 'package:bb_mobile/features/exchange_access/domain/repositories/exchange_access_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExchangeAccessRepositoryImpl implements ExchangeAccessRepository {
  static const key = 'exchange_access_v1';

  @override
  Future<Result<Map<bool, ExchangeAccess>, ExchangeAccessFailure>>
  read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.get(key);
      if (raw == null) return const Ok({});
      if (raw is! String) {
        return const Err(ExchangeAccessInvalidFormatFailure());
      }
      try {
        return Ok(ExchangeAccessModel.decode(jsonDecode(raw)));
      } on Exception catch (_) {
        return const Err(ExchangeAccessInvalidFormatFailure());
      }
    } on Exception catch (_) {
      return const Err(ExchangeAccessStorageFailure());
    }
  }

  @override
  Future<Result<void, ExchangeAccessFailure>> write(
    Map<bool, ExchangeAccess> values,
  ) async {
    try {
      final data = ExchangeAccessModel.encode(values);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, jsonEncode(data))) {
        return const Err(ExchangeAccessStorageFailure());
      }
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(ExchangeAccessStorageFailure());
    }
  }
}
