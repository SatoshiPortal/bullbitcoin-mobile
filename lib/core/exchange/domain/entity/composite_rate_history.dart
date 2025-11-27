import 'package:bb_mobile/core/exchange/domain/entity/rate_history.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'composite_rate_history.freezed.dart';

@freezed
sealed class CompositeRateHistory with _$CompositeRateHistory {
  const factory CompositeRateHistory({
    required RateHistory latest,
    required RateHistory day,
    required RateHistory month,
    required RateHistory years,
  }) = _CompositeRateHistory;

  const CompositeRateHistory._();

  List<Rate> getAllRates() {
    final allRates = <Rate>[];

    if (latest.rates != null && latest.rates!.isNotEmpty) {
      allRates.addAll(latest.rates!);
    }

    if (years.rates != null && years.rates!.isNotEmpty) {
      allRates.addAll(years.rates!);
    }

    allRates.sort((a, b) {
      final dateA = a.createdAt;
      final dateB = b.createdAt;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    });

    return allRates;
  }

  bool isValid() {
    final latestCount = latest.rates?.length ?? 0;
    final dayCount = day.rates?.length ?? 0;
    final monthCount = month.rates?.length ?? 0;
    final yearsCount = years.rates?.length ?? 0;
    const maxYearsCount = 52 * 4;

    return latestCount == 1 &&
        dayCount == 0 &&
        monthCount == 0 &&
        yearsCount <= maxYearsCount;
  }
}
