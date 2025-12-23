class UpdateMempoolSettingsRequest {
  final bool isLiquid;
  final bool useForFeeEstimation;

  UpdateMempoolSettingsRequest({
    required this.isLiquid,
    required this.useForFeeEstimation,
  });
}
