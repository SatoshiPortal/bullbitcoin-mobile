typedef QrScanningLabels = ({
  String Function(String) scanningProgressLabel,
  String Function(String) urProgressLabel,
  String scanningCompletedMessage,
  String urDecodingFailedMessage,
  String urProcessingFailedMessage,
});

typedef NfcScanningLabels = ({
  String scanNfcButton,
  String nfcConnectionLost,
  String nfcWriteFailed,
  String nfcDisabled,
  String nfcNotAvailable,
  String nfcError,
  String nfcInvalidData,
});
