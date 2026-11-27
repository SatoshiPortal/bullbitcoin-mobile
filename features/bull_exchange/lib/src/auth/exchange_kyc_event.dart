sealed class ExchangeKycEvent {
  const ExchangeKycEvent();
}

/// The WebView moved to a page outside the KYC flow.
final class KycLeftFlow extends ExchangeKycEvent {
  const KycLeftFlow();
}

final class KycCloseRequested extends ExchangeKycEvent {
  const KycCloseRequested();
}
