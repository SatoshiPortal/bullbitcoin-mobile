import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/complete_exchange_authentication_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_web_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_failure_banner.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_failure_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:bull_ui/bull_ui.dart' show BullDialog;

class ExchangeAuthScreen extends StatefulWidget {
  final VoidCallback onExit;

  const ExchangeAuthScreen({required this.onExit, super.key});

  @override
  State<ExchangeAuthScreen> createState() => _ExchangeAuthScreenState();
}

class _ExchangeAuthScreenState extends State<ExchangeAuthScreen> {
  late final WebViewController _controller = WebViewController();
  late final WebviewCookieManager _cookieManager = WebviewCookieManager();
  late final String _bbAuthUrl;
  late final CompleteExchangeAuthenticationUsecase _authentication;
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
    final result = await locator<GetExchangeWebSettingsUsecase>().execute();
    if (!mounted) return;
    final SettingsEntity settingsState;
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
    _authentication = locator<CompleteExchangeAuthenticationUsecase>(
      param1: _controller.runJavaScriptReturningResult,
      param2: (isTestnet: isTestnet, isOpen: () => mounted && !_isClosing),
    );
    _bbAuthUrl = isTestnet
        ? ApiServiceConstants.bbAuthTestUrl
        : ApiServiceConstants.bbAuthUrl;
    if (isTestnet) {
      _basicAuthUsername = settingsState.exchangeTestnetBasicAuthUsername;
      _basicAuthPassword = settingsState.exchangeTestnetBasicAuthPassword;
    }

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
            // Direct JavaScript to handle "Back to App" button
            _controller.runJavaScript('''
              (function() {
                function handleBackToApp() {
                  // NOTE : NEXT JS MAY CHANGE THE NAME OF THIS DIV!!!
                  
                  // Method 1: Direct click on the specific div structure
                  const backDiv = document.querySelector('div.css-70qvj9');
                  if (backDiv && !backDiv.hasAttribute('data-handled')) {
                    backDiv.setAttribute('data-handled', 'true');
                    backDiv.addEventListener('click', function(e) {
                      e.preventDefault();
                      e.stopPropagation();
                      Flutter.postMessage('close');
                      return false;
                    });
                  }
                  
                  // Method 2: Click on parent div
                  // const parentDiv = document.querySelector('div.css-17lzdhk');
                  // if (parentDiv && !parentDiv.hasAttribute('data-handled')) {
                  //   parentDiv.setAttribute('data-handled', 'true');
                  //   parentDiv.addEventListener('click', function(e) {
                  //     e.preventDefault();
                  //     e.stopPropagation();
                  //     Flutter.postMessage('close');
                  //     return false;
                  //   });
                  // }
                }
                
                // Run immediately
                handleBackToApp();
                
                // Run after delays to catch dynamic content
                setTimeout(handleBackToApp, 500);
                setTimeout(handleBackToApp, 1000);
                setTimeout(handleBackToApp, 2000);
                setTimeout(handleBackToApp, 5000);
                
                // Watch for DOM changes
                const observer = new MutationObserver(function(mutations) {
                  handleBackToApp();
                });
                
                observer.observe(document.body, {
                  childList: true,
                  subtree: true
                });
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
            final bbSessionCookie = await _tryGetBBSessionCookie(url);
            // If no bb_session cookie is found, do nothing as the user is not
            //  logged in yet.
            if (bbSessionCookie == null) return;

            if (!mounted || _isClosing || _isGeneratingApiKey) return;
            var retry = false;
            setState(() => _isGeneratingApiKey = true);
            try {
              final failure = await context
                  .read<ExchangeCubit>()
                  .completeAuthentication(_authentication);
              if (!mounted || _isClosing) return;
              if (failure != null) retry = await _handleLoginError(failure);
            } on Exception catch (error) {
              log.warning(
                'Exchange authentication failed: ${error.runtimeType}',
              );
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
              // Host only — never the full URL, whose query params may
              // carry tokens.
              log.warning(
                'Blocked webview navigation: '
                '${uri == null ? 'unparseable URL' : 'non-https host ${uri.host}'}',
              );
              return NavigationDecision.prevent;
            }

            final authHost = Uri.parse(_bbAuthUrl).host;
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
            log.warning('Blocked webview navigation to host: ${uri.host}');
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
      ..loadRequest(Uri.parse(_bbAuthUrl));

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
            ExchangeFailureBanner(failure: failure, onRetry: _retry),
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

  Future<String?> _tryGetBBSessionCookie(String url) async {
    final cookies = await _cookieManager.getCookies(url);
    String? bbSessionCookie;
    for (final cookie in cookies) {
      if (cookie.name == 'bb_session') {
        bbSessionCookie = cookie.value;
        break;
      }
    }
    return bbSessionCookie;
  }

  /// Retry preserves the web session; only explicit sign-out clears cookies.
  Future<bool> _handleLoginError([ExchangeFailure? failure]) async {
    if (!mounted || _isClosing) return false;
    return await BullDialog.show<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.loc.exchangeAuthLoginFailedTitle),
            content: Text(
              failure?.toTranslated(context) ??
                  context.loc.exchangeAuthLoginFailedMessage,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.loc.exchangeAuthLoginFailedOkButton),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.loc.retry),
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
