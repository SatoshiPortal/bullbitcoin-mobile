import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

/// What the sign-in WebView needs once the web settings are read.
@immutable
final class ExchangeAuthConfig {
  final bool isTestnet;
  final Uri signInUrl;
  final ({String username, String password})? basicAuth;

  const ExchangeAuthConfig({
    required this.isTestnet,
    required this.signInUrl,
    this.basicAuth,
  });

  @override
  bool operator ==(Object other) =>
      other is ExchangeAuthConfig &&
      other.isTestnet == isTestnet &&
      other.signInUrl == signInUrl &&
      other.basicAuth == basicAuth;

  @override
  int get hashCode => Object.hash(isTestnet, signInUrl, basicAuth);
}

@immutable
sealed class ExchangeAuthState {
  const ExchangeAuthState();

  ExchangeAuthState next(ExchangeAuthEvent event) {
    final state = this;
    return switch ((state, event)) {
      (
        AuthDone() || AuthClosing(),
        AuthConfigLoaded() ||
            AuthConfigUnavailable() ||
            AuthRetryRequested() ||
            AuthWebSessionSeen() ||
            AuthKeyStored() ||
            AuthKeyDeferred() ||
            AuthKeyNotStored() ||
            AuthErrorAcknowledged() ||
            AuthCloseRequested(),
      ) =>
        state,
      (
        AuthLoadingConfig() ||
            AuthConfigFailed() ||
            AuthBrowsing() ||
            AuthGeneratingKey() ||
            AuthKeyFailed(),
        AuthCloseRequested(),
      ) =>
        const AuthClosing(),

      (AuthLoadingConfig(), AuthConfigLoaded(:final config)) => AuthBrowsing(
        config,
      ),
      (AuthLoadingConfig(), AuthConfigUnavailable(:final failure)) =>
        AuthConfigFailed(failure),
      (AuthConfigFailed(), AuthRetryRequested()) => const AuthLoadingConfig(),
      (AuthBrowsing(:final config), AuthWebSessionSeen()) => AuthGeneratingKey(
        config,
      ),
      (AuthGeneratingKey(), AuthKeyStored()) => const AuthDone(),
      (AuthGeneratingKey(:final config), AuthKeyDeferred()) => AuthBrowsing(
        config,
      ),
      (AuthGeneratingKey(:final config), AuthKeyNotStored(:final failure)) =>
        AuthKeyFailed(config, failure),
      (AuthKeyFailed(:final config), AuthErrorAcknowledged()) => AuthBrowsing(
        config,
      ),

      (
        AuthLoadingConfig() ||
            AuthConfigFailed() ||
            AuthBrowsing() ||
            AuthGeneratingKey() ||
            AuthKeyFailed(),
        AuthConfigLoaded() ||
            AuthConfigUnavailable() ||
            AuthRetryRequested() ||
            AuthWebSessionSeen() ||
            AuthKeyStored() ||
            AuthKeyDeferred() ||
            AuthKeyNotStored() ||
            AuthErrorAcknowledged(),
      ) =>
        state,
    };
  }
}

final class AuthLoadingConfig extends ExchangeAuthState {
  const AuthLoadingConfig();

  @override
  bool operator ==(Object other) => other is AuthLoadingConfig;

  @override
  int get hashCode => (AuthLoadingConfig).hashCode;
}

final class AuthConfigFailed extends ExchangeAuthState {
  final ExchangeFailure failure;

  const AuthConfigFailed(this.failure);

  @override
  bool operator ==(Object other) =>
      other is AuthConfigFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

final class AuthBrowsing extends ExchangeAuthState {
  final ExchangeAuthConfig config;

  const AuthBrowsing(this.config);

  @override
  bool operator ==(Object other) =>
      other is AuthBrowsing && other.config == config;

  @override
  int get hashCode => Object.hash(AuthBrowsing, config);
}

/// One API key generation at a time: URL changes meanwhile are a stay.
final class AuthGeneratingKey extends ExchangeAuthState {
  final ExchangeAuthConfig config;

  const AuthGeneratingKey(this.config);

  @override
  bool operator ==(Object other) =>
      other is AuthGeneratingKey && other.config == config;

  @override
  int get hashCode => Object.hash(AuthGeneratingKey, config);
}

/// The key could not be stored; the user acknowledges or retries.
final class AuthKeyFailed extends ExchangeAuthState {
  final ExchangeAuthConfig config;
  final ExchangeFailure failure;

  const AuthKeyFailed(this.config, this.failure);

  @override
  bool operator ==(Object other) =>
      other is AuthKeyFailed &&
      other.config == config &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(config, failure);
}

/// The key is stored: the screen leaves, whatever the account read does.
final class AuthDone extends ExchangeAuthState {
  const AuthDone();

  @override
  bool operator ==(Object other) => other is AuthDone;

  @override
  int get hashCode => (AuthDone).hashCode;
}

final class AuthClosing extends ExchangeAuthState {
  const AuthClosing();

  @override
  bool operator ==(Object other) => other is AuthClosing;

  @override
  int get hashCode => (AuthClosing).hashCode;
}

@immutable
sealed class ExchangeAuthEvent {
  const ExchangeAuthEvent();
}

final class AuthConfigLoaded extends ExchangeAuthEvent {
  final ExchangeAuthConfig config;

  const AuthConfigLoaded(this.config);
}

final class AuthConfigUnavailable extends ExchangeAuthEvent {
  final ExchangeFailure failure;

  const AuthConfigUnavailable(this.failure);
}

final class AuthRetryRequested extends ExchangeAuthEvent {
  const AuthRetryRequested();
}

/// The WebView reached a page with a web session cookie.
final class AuthWebSessionSeen extends ExchangeAuthEvent {
  const AuthWebSessionSeen();
}

final class AuthKeyStored extends ExchangeAuthEvent {
  const AuthKeyStored();
}

/// The web session is not ready for a key yet; keep browsing.
final class AuthKeyDeferred extends ExchangeAuthEvent {
  const AuthKeyDeferred();
}

final class AuthKeyNotStored extends ExchangeAuthEvent {
  final ExchangeFailure failure;

  const AuthKeyNotStored(this.failure);
}

final class AuthErrorAcknowledged extends ExchangeAuthEvent {
  const AuthErrorAcknowledged();
}

/// Back, the close button or the site's "Back to App".
final class AuthCloseRequested extends ExchangeAuthEvent {
  const AuthCloseRequested();
}

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
