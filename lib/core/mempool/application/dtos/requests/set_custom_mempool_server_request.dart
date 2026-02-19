class SetCustomMempoolServerRequest {
  final String url;
  final bool isLiquid;
  final bool enableSsl;

  SetCustomMempoolServerRequest({
    required this.url,
    required this.isLiquid,
    this.enableSsl = true,
  });
}
