import 'exchange_kyc_event.dart';

/// KYC WebView: once it starts leaving, further redirects are a stay (B15).
enum ExchangeKycState {
  browsing,
  leaving;

  ExchangeKycState next(ExchangeKycEvent event) {
    final state = this;
    return switch ((state, event)) {
      (ExchangeKycState.browsing, KycLeftFlow() || KycCloseRequested()) =>
        ExchangeKycState.leaving,
      (ExchangeKycState.leaving, KycLeftFlow() || KycCloseRequested()) => state,
    };
  }
}
