import 'dart:math' show pow;

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate_history.dart'
    as entity;
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rate_history_model.freezed.dart';
part 'rate_history_model.g.dart';

@freezed
sealed class RateModel with _$RateModel {
  const factory RateModel({
    String? fromCurrency,
    String? toCurrency,
    int? marketPrice,
    int? price,
    String? priceCurrency,
    int? precision,
    int? indexPrice,
    int? userPrice,
    String? createdAt,
  }) = _RateModel;

  factory RateModel.fromJson(Map<String, dynamic> json) =>
      _$RateModelFromJson(json);

  const RateModel._();

  entity.Rate toEntity() {
    final precisionValue = precision ?? 2;
    final precisionDivisor = pow(10, precisionValue);

    return entity.Rate(
      fromCurrency:
          fromCurrency != null ? FiatCurrency.fromCode(fromCurrency!) : null,
      toCurrency: toCurrency ?? 'BTC',
      marketPrice: marketPrice != null ? marketPrice! / precisionDivisor : null,
      price: price != null ? price! / precisionDivisor : null,
      priceCurrency: priceCurrency,
      precision: precision,
      indexPrice: indexPrice != null ? indexPrice! / precisionDivisor : null,
      userPrice: userPrice != null ? userPrice! / precisionDivisor : null,
      createdAt: createdAt != null ? DateTime.parse(createdAt!) : null,
    );
  }

  factory RateModel.fromEntity(entity.Rate entity) {
    final precisionValue = entity.precision ?? 2;
    final precisionMultiplier = pow(10, precisionValue);

    return RateModel(
      fromCurrency: entity.fromCurrency?.code,
      toCurrency: entity.toCurrency ?? 'BTC',
      marketPrice:
          entity.marketPrice != null
              ? (entity.marketPrice! * precisionMultiplier).round()
              : null,
      price:
          entity.price != null
              ? (entity.price! * precisionMultiplier).round()
              : null,
      priceCurrency: entity.priceCurrency,
      precision: entity.precision,
      indexPrice:
          entity.indexPrice != null
              ? (entity.indexPrice! * precisionMultiplier).round()
              : null,
      userPrice:
          entity.userPrice != null
              ? (entity.userPrice! * precisionMultiplier).round()
              : null,
      createdAt: entity.createdAt?.toIso8601String(),
    );
  }
}

extension RateModelSqlite on RateModel {
  RateHistoryRow toSqlite({
    required String fromCurrency,
    required String toCurrency,
    required String interval,
  }) {
    final precisionValue = precision ?? 2;
    final precisionDivisor = pow(10, precisionValue);

    return RateHistoryRow(
      id: 0,
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      interval: interval,
      marketPrice: marketPrice != null ? marketPrice! / precisionDivisor : null,
      price: price != null ? price! / precisionDivisor : null,
      priceCurrency: priceCurrency,
      precision: precision,
      indexPrice: indexPrice != null ? indexPrice! / precisionDivisor : null,
      userPrice: userPrice != null ? userPrice! / precisionDivisor : null,
      createdAt: createdAt ?? DateTime.now().toUtc().toIso8601String(),
    );
  }

  static RateModel fromSqlite(RateHistoryRow row) {
    final precisionValue = row.precision ?? 2;
    final precisionMultiplier = pow(10, precisionValue);

    return RateModel(
      fromCurrency: row.fromCurrency,
      toCurrency: row.toCurrency,
      marketPrice:
          row.marketPrice != null
              ? (row.marketPrice! * precisionMultiplier).round()
              : null,
      price:
          row.price != null ? (row.price! * precisionMultiplier).round() : null,
      priceCurrency: row.priceCurrency,
      precision: row.precision,
      indexPrice:
          row.indexPrice != null
              ? (row.indexPrice! * precisionMultiplier).round()
              : null,
      userPrice:
          row.userPrice != null
              ? (row.userPrice! * precisionMultiplier).round()
              : null,
      createdAt: row.createdAt,
    );
  }
}

@freezed
sealed class RateHistoryModel with _$RateHistoryModel {
  const factory RateHistoryModel({
    String? fromCurrency,
    String? toCurrency,
    int? precision,
    String? interval,
    List<RateModel>? rates,
  }) = _RateHistoryModel;

  factory RateHistoryModel.fromJson(Map<String, dynamic> json) =>
      _$RateHistoryModelFromJson(json);

  const RateHistoryModel._();

  entity.RateHistory toEntity() {
    return entity.RateHistory(
      fromCurrency:
          fromCurrency != null ? FiatCurrency.fromCode(fromCurrency!) : null,
      toCurrency: toCurrency ?? 'BTC',
      precision: precision,
      interval:
          interval != null
              ? entity.RateTimelineInterval.fromString(interval!)
              : null,
      rates: rates?.map((r) => r.toEntity()).toList(),
    );
  }

  factory RateHistoryModel.fromEntity(entity.RateHistory entity) {
    return RateHistoryModel(
      fromCurrency: entity.fromCurrency?.code,
      toCurrency: entity.toCurrency ?? 'BTC',
      precision: entity.precision,
      interval: entity.interval?.value,
      rates: entity.rates?.map((r) => RateModel.fromEntity(r)).toList(),
    );
  }
}
