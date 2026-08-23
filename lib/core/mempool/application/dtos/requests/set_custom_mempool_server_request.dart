class SetCustomMempoolServerRequest {
  final String url;
  final bool isLiquid;
  final bool enableSsl;
  final bool validateDomain;

  SetCustomMempoolServerRequest({
    required this.url,
    required this.isLiquid,
    this.enableSsl = true,
    this.validateDomain = false,
  });
}
