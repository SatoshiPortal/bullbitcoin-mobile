import '../exchange_l10n.dart';
import 'exchange_auth_machine.dart';

import 'package:bull_ui/bull_ui.dart' show BullButton, BullButtonSize;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDialog, BullFadingLinearProgress, BullInfoCard, BullShapesX;

typedef ExchangeAuthHost = ({
  Future<Result<ExchangeWebPreferences, ExchangeFailure>> Function()
  loadConfiguration,
  Future<Result<void, ExchangeFailure>> Function(
    BuildContext,
    Future<Object> Function(String), {
    required bool isTestnet,
    required bool Function() isCurrent,
  })
  authenticate,
  String Function(BuildContext, ExchangeFailure) failureMessage,
  Uri mainnetSignInUrl,
  Uri testnetSignInUrl,
  Uri returnUrl,
  Uri testnetKycUrl,
  ExchangeAccess Function() currentAccess,
  Stream<ExchangeAccess> Function() watchAccess,
  Future<void> Function(BuildContext) retryAccess,
});

/// The sign-in WebView, driven by [transitionAuth]. [onDone] runs once, when
/// the API key is stored; [onExit] once, when the user leaves first.
class ExchangeAuthScreen extends StatefulWidget {
  final VoidCallback onExit;
  final VoidCallback onDone;
  final ExchangeAuthHost host;

  const ExchangeAuthScreen({
    required this.onExit,
    required this.onDone,
    required this.host,
    super.key,
  });

  @override
  State<ExchangeAuthScreen> createState() => _ExchangeAuthScreenState();
}

class _ExchangeAuthScreenState extends State<ExchangeAuthScreen> {
  late final WebViewController _controller = WebViewController();
  late final WebViewCookieManager _cookieManager = WebViewCookieManager();
  ExchangeAuthState _state = const AuthLoadingConfig();
  bool _webViewConfigured = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfiguration());
  }

  void _add(ExchangeAuthEvent event) {
    if (!mounted) return;
    final previous = _state;
    final next = transitionAuth(previous, event);
    if (next == previous) return;
    setState(() => _state = next);
    switch (next) {
      case AuthLoadingConfig():
        unawaited(_loadConfiguration());
      case AuthBrowsing(:final config) when !_webViewConfigured:
        _webViewConfigured = true;
        _configureWebView(config);
      case AuthGeneratingKey(:final config):
        unawaited(_generateKey(config));
      case AuthKeyFailed(:final failure):
        unawaited(_showKeyFailure(failure));
      case AuthDone():
        widget.onDone();
      case AuthClosing():
        widget.onExit();
      case AuthConfigFailed() || AuthBrowsing():
        break;
    }
  }

  Future<void> _loadConfiguration() async {
    final result = await widget.host.loadConfiguration();
    _add(switch (result) {
      Ok(:final value) => AuthConfigLoaded(
        ExchangeAuthConfig(
          isTestnet: value.environment == Environment.testnet,
          signInUrl: value.environment == Environment.testnet
              ? widget.host.testnetSignInUrl
              : widget.host.mainnetSignInUrl,
          basicAuth: _testnetBasicAuth(value),
        ),
      ),
      Err(:final failure) => AuthConfigUnavailable(failure),
    });
  }

  static ({String username, String password})? _testnetBasicAuth(
    ExchangeWebPreferences preferences,
  ) {
    final username = preferences.exchangeTestnetBasicAuthUsername;
    final password = preferences.exchangeTestnetBasicAuthPassword;
    if (preferences.environment != Environment.testnet ||
        username == null ||
        password == null) {
      return null;
    }
    return (username: username, password: password);
  }

  Future<void> _generateKey(ExchangeAuthConfig config) async {
    ExchangeAuthEvent outcome;
    try {
      final result = await widget.host.authenticate(
        context,
        _controller.runJavaScriptReturningResult,
        isTestnet: config.isTestnet,
        isCurrent: () => mounted && _state is AuthGeneratingKey,
      );
      outcome = switch (result) {
        Ok() => const AuthKeyStored(),
        Err(failure: ExchangeAuthenticationDeferredFailure()) =>
          const AuthKeyDeferred(),
        Err(:final failure) => AuthKeyNotStored(failure),
      };
    } on Exception {
      log.warning('Exchange auth failed reason=platform');
      outcome = const AuthKeyNotStored(ExchangeUnexpectedFailure('platform'));
    }
    _add(outcome);
  }

  Future<void> _showKeyFailure(ExchangeFailure failure) async {
    final retry = await _handleLoginError(failure);
    if (!mounted || _state is! AuthKeyFailed) return;
    _add(const AuthErrorAcknowledged());
    if (retry && _state is AuthBrowsing) await _controller.reload();
  }

  void _configureWebView(ExchangeAuthConfig config) {
    final isTestnet = config.isTestnet;
    // Hosts of the Bull web app the site links back to.
    final appHosts = {
      widget.host.returnUrl.host,
      if (isTestnet) widget.host.testnetKycUrl.host,
    }.toList();

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'close') _add(const AuthCloseRequested());
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // The site's "Back to App" control is a link to the Bull web app,
            // which this WebView never loads: a tap on it leaves the screen
            // like the back gesture does. Redirects to that host stay
            // refused, so a sign-in that ends there is not cut short.
            _controller.runJavaScript('''
              (function() {
                if (window.__bullBackToApp) return;
                window.__bullBackToApp = true;
                const hosts = ${jsonEncode(appHosts)};
                document.addEventListener('click', function(e) {
                  const link = e.target.closest && e.target.closest('a[href]');
                  if (!link) return;
                  let host;
                  try { host = new URL(link.href, location.href).host; }
                  catch (_) { return; }
                  if (hosts.indexOf(host) === -1) return;
                  e.preventDefault();
                  e.stopPropagation();
                  Flutter.postMessage('close');
                }, true);
              })();
            ''');
          },
          onUrlChange: (UrlChange change) async {
            final url = change.url;
            if (url == null) return;

            // During sign-up, the bb_session cookie is set before email
            // verification. Skip processing on these paths so the WebView
            // stays open and the user can complete email verification. Once
            // done, the auth app navigates away and the API key is generated
            // on the next URL change.
            if (url.contains('/registration') ||
                url.contains('/verification')) {
              return;
            }

            // Only a page with the web session cookie can produce a key.
            if (_state is! AuthBrowsing) return;
            if (!await _hasBBSessionCookie(url)) return;
            _add(const AuthWebSessionSeen());
          },
          onNavigationRequest: (NavigationRequest request) {
            // Exact host matching — a startsWith('https://accounts') prefix
            // check would also match lookalike hosts such as
            // https://accounts.evil.com.
            final uri = Uri.tryParse(request.url);
            if (uri == null || uri.scheme != 'https') {
              log.warning(
                'Exchange navigation refused reason=${uri == null ? 'parse' : 'scheme'}',
              );
              return NavigationDecision.prevent;
            }

            final authHost = config.signInUrl.host;
            if (uri.host == authHost) {
              return NavigationDecision.navigate;
            }

            if (uri.host == 'www.bullbitcoin.com' &&
                (request.url.contains('terms') ||
                    request.url.contains('privacy'))) {
              return NavigationDecision.navigate;
            }

            // Logged so a legitimate navigation blocked in the field (e.g.
            // a cross-host redirect between auth instances) is diagnosable
            // from user logs.
            log.warning('Exchange navigation refused reason=host');
            return NavigationDecision.prevent;
          },
          onHttpAuthRequest: (HttpAuthRequest request) {
            final auth = config.basicAuth;
            if (auth == null) {
              request.onCancel();
              return;
            }
            request.onProceed(
              WebViewCredential(user: auth.username, password: auth.password),
            );
          },
        ),
      )
      // TODO: Is this user agent necessary?
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15.0 Safari/604.1',
      )
      ..loadRequest(config.signInUrl);

    if (Platform.isAndroid) {
      AndroidWebViewController.enableDebugging(false);
      final platformController = _controller.platform;
      if (platformController is AndroidWebViewController) {
        platformController.setMediaPlaybackRequiresUserGesture(false);
      }
    } else if (Platform.isIOS) {
      final platformController = _controller.platform;
      if (platformController is WebKitWebViewController) {
        platformController.setAllowsBackForwardNavigationGestures(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = switch (_state) {
      AuthLoadingConfig() || AuthGeneratingKey() || AuthDone() => true,
      AuthConfigFailed() ||
      AuthBrowsing() ||
      AuthKeyFailed() ||
      AuthClosing() => false,
    };
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullFadingLinearProgress(trigger: busy),
          Expanded(
            child: switch (_state) {
              AuthLoadingConfig() ||
              AuthGeneratingKey() ||
              AuthDone() => const SizedBox.shrink(),
              AuthConfigFailed(:final failure) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CloseButton(
                    onPressed: () => _add(const AuthCloseRequested()),
                  ),
                  BullInfoCard(
                    description: widget.host.failureMessage(context, failure),
                    tagColor: context.appColors.error,
                    bgColor: context.appColors.errorContainer,
                    onTap: () => _add(const AuthRetryRequested()),
                  ),
                ],
              ),
              AuthBrowsing() ||
              AuthKeyFailed() ||
              AuthClosing() => WebViewWidget(controller: _controller),
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _hasBBSessionCookie(String url) async {
    final cookies = await _cookieManager.getCookies(domain: Uri.parse(url));
    // Authentication runs in the WebView; only session presence is needed here.
    return cookies.any((cookie) => cookie.name == 'bb_session');
  }

  /// OK returns to the same web session; Retry reloads it.
  /// Only explicit sign-out clears cookies.
  Future<bool> _handleLoginError(ExchangeFailure failure) async {
    if (!mounted) return false;
    return await BullDialog.show<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                dialogContext.bullShapes.sheet,
              ),
            ),
            title: Text(context.loc.exchangeAuthLoginFailedTitle),
            content: Text(
              failure is ExchangeUnexpectedFailure
                  ? context.loc.exchangeAuthLoginFailedMessage
                  : widget.host.failureMessage(context, failure),
            ),
            actions: [
              BullButton.secondary(
                label: context.loc.exchangeAuthLoginFailedOkButton,
                onPressed: () => Navigator.of(dialogContext).pop(false),
                size: BullButtonSize.small,
                compact: true,
              ),
              BullButton.secondary(
                label: context.loc.retry,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                size: BullButtonSize.small,
                compact: true,
              ),
            ],
          ),
        ) ??
        false;
  }
}
