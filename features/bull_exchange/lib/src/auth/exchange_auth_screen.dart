import '../exchange_l10n.dart';

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
    show BullDialog, BullInfoCard, BullShapesX;

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
  Stream<bool> Function(BuildContext) accountSignedInChanges,
  Future<void> Function(BuildContext) retryAccess,
});

class ExchangeAuthScreen extends StatefulWidget {
  final VoidCallback onExit;
  final ExchangeAuthHost host;

  const ExchangeAuthScreen({
    required this.onExit,
    required this.host,
    super.key,
  });

  @override
  State<ExchangeAuthScreen> createState() => _ExchangeAuthScreenState();
}

class _ExchangeAuthScreenState extends State<ExchangeAuthScreen> {
  late final WebViewController _controller = WebViewController();
  late final WebViewCookieManager _cookieManager = WebViewCookieManager();
  late final Uri _bbAuthUrl;
  String? _basicAuthUsername;
  String? _basicAuthPassword;
  bool _isGeneratingApiKey = false;
  bool _isClosing = false;

  bool _isLoadingConfiguration = true;
  ExchangeFailure? _configurationFailure;

  @override
  void initState() {
    super.initState();

    unawaited(_load());
  }

  Future<void> _retry() async {
    setState(() {
      _isLoadingConfiguration = true;
      _configurationFailure = null;
    });
    await _load();
  }

  Future<void> _load() async {
    final result = await widget.host.loadConfiguration();
    if (!mounted) return;
    final ExchangeWebPreferences settingsState;
    switch (result) {
      case Ok(:final value):
        settingsState = value;
      case Err(:final failure):
        setState(() {
          _isLoadingConfiguration = false;
          _configurationFailure = failure;
        });
        return;
    }
    final isTestnet = settingsState.environment == Environment.testnet;
    _bbAuthUrl = isTestnet
        ? widget.host.testnetSignInUrl
        : widget.host.mainnetSignInUrl;
    if (isTestnet) {
      _basicAuthUsername = settingsState.exchangeTestnetBasicAuthUsername;
      _basicAuthPassword = settingsState.exchangeTestnetBasicAuthPassword;
    }

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
          if (message.message == 'close') {
            if (!_isClosing && mounted) {
              _isClosing = true;
              // Navigate immediately
              widget.onExit();
            }
          }
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

            // Check if the URL contains the bb_session cookie
            final hasSession = await _hasBBSessionCookie(url);
            // If no bb_session cookie is found, do nothing as the user is not
            //  logged in yet.
            if (!hasSession) return;

            if (!mounted || _isClosing || _isGeneratingApiKey) return;
            var retry = false;
            setState(() => _isGeneratingApiKey = true);
            try {
              final result = await widget.host.authenticate(
                context,
                _controller.runJavaScriptReturningResult,
                isTestnet: isTestnet,
                isCurrent: () => mounted && !_isClosing,
              );
              final failure = switch (result) {
                Err(:final failure) => failure,
                Ok() => null,
              };
              if (!mounted || _isClosing) return;
              if (failure != null &&
                  failure is! ExchangeAuthenticationDeferredFailure) {
                retry = await _handleLoginError(failure);
              }
            } on Exception {
              log.warning('Exchange auth failed reason=platform');
              if (mounted && !_isClosing) retry = await _handleLoginError();
            } finally {
              if (mounted) setState(() => _isGeneratingApiKey = false);
            }
            if (retry && mounted && !_isClosing) await _controller.reload();
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

            final authHost = _bbAuthUrl.host;
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
            final username = _basicAuthUsername;
            final password = _basicAuthPassword;
            if (username == null || password == null) {
              request.onCancel();
              return;
            }
            request.onProceed(
              WebViewCredential(user: username, password: password),
            );
          },
        ),
      )
      // TODO: Is this user agent necessary?
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15.0 Safari/604.1',
      )
      ..loadRequest(_bbAuthUrl);

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
    setState(() => _isLoadingConfiguration = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingConfiguration) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (_configurationFailure case final failure?) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CloseButton(onPressed: widget.onExit),
            BullInfoCard(
              description: widget.host.failureMessage(context, failure),
              tagColor: context.appColors.error,
              bgColor: context.appColors.errorContainer,
              onTap: _retry,
            ),
          ],
        ),
      );
    }
    return SafeArea(
      child: _isGeneratingApiKey
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _controller),
    );
  }

  Future<bool> _hasBBSessionCookie(String url) async {
    final cookies = await _cookieManager.getCookies(domain: Uri.parse(url));
    // Authentication runs in the WebView; only session presence is needed here.
    return cookies.any((cookie) => cookie.name == 'bb_session');
  }

  /// OK returns to the same web session; Retry reloads it.
  /// Only explicit sign-out clears cookies.
  Future<bool> _handleLoginError([ExchangeFailure? failure]) async {
    if (!mounted || _isClosing) return false;
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
              (failure == null
                      ? null
                      : widget.host.failureMessage(context, failure)) ??
                  context.loc.exchangeAuthLoginFailedMessage,
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

  @override
  void dispose() {
    _isClosing = true;
    super.dispose();
  }
}
