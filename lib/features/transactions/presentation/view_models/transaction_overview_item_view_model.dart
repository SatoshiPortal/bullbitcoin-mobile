import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_overview_item_view_model.freezed.dart';

@freezed
sealed class TransactionOverviewItemViewModel
    with _$TransactionOverviewItemViewModel {
  const factory TransactionOverviewItemViewModel({
    required String id,
    required String title,
    required String subtitle,
    required String amount,
    required String date,
    required String iconPath,
  }) = _TransactionOverviewItemViewModel;

  const TransactionOverviewItemViewModel._();
}
