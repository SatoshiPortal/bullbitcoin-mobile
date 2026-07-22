import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_auth_navigation_policy.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class ExchangeAuthScreen extends StatefulWidget {
  const ExchangeAuthScreen({super.key, this.returnToCaller = false});

  /// When true, completing (or dismissing) the login pops back to the screen
  /// that pushed it instead of navigating to the wallet home. Used by the fiat
  /// settlement reconnect flow so the merchant returns to their in-progress
  /// activation with selections preserved.
  final bool returnToCaller;

  @override
  State<ExchangeAuthScreen> createState() => _ExchangeAuthScreenState();
}

class _ExchangeAuthScreenState extends State<ExchangeAuthScreen> {
  late final WebViewController _controller = WebViewController();
  late final WebviewCookieManager _cookieManager = WebviewCookieManager();
  late final String _bbAuthUrl;
  late final bool _isTestnet;
  String? _basicAuthUsername;
  String? _basicAuthPassword;
  bool _isGeneratingApiKey = false;
  bool _credentialImportComplete = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();

    final settingsState = context.read<SettingsCubit>().state;
    _isTestnet = settingsState.environment == Environment.testnet;
    _bbAuthUrl = _isTestnet
        ? ApiServiceConstants.bbAuthTestUrl
        : ApiServiceConstants.bbAuthUrl;
    if (_isTestnet) {
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
              if (widget.returnToCaller && context.canPop()) {
                context.pop();
              } else {
                context.goNamed(WalletRoute.walletHome.name);
              }
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
            if (url == null ||
                !mounted ||
                _isClosing ||
                _isGeneratingApiKey ||
                _credentialImportComplete) {
              return;
            }

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
            if (!mounted ||
                _isClosing ||
                _isGeneratingApiKey ||
                _credentialImportComplete) {
              return;
            }
            // If no bb_session cookie is found, do nothing as the user is not
            //  logged in yet.
            if (bbSessionCookie == null) return;

            // If the bb_session cookie is found, the user is logged in and
            //  we can proceed to try to generate and save the API key.

            final exchangeCubit = context.read<ExchangeCubit>();
            try {
              // Set the flag to indicate that we are generating the API key
              setState(() => _isGeneratingApiKey = true);

              final apiKeyData = await _generateApiKey();
              // Save the API key so it can be used for future requests
              if (!mounted || _isClosing) return;
              await exchangeCubit.storeApiKey(
                apiKeyData,
                isTestnet: _isTestnet,
              );

              // Check if the API key was successfully stored
              final saveApiKeyException =
                  exchangeCubit.state.saveApiKeyException;
              if (saveApiKeyException != null) {
                throw StateError('Unable to import Bull Bitcoin credentials');
              }

              _credentialImportComplete = true;
            } catch (_) {
              log.warning('Unable to import Bull Bitcoin credentials');
              if (mounted && !_isClosing) {
                try {
                  await _handleLoginError();
                } catch (_) {
                  log.warning('Unable to reset Bull Bitcoin login');
                }
              }
            } finally {
              // Reset the flag after the API key generation process is done
              //  and if the widget is still mounted.
              if (mounted) {
                setState(() => _isGeneratingApiKey = false);
              }
            }

            if (!_credentialImportComplete) return;

            await _refreshAccountAfterCredentialImport(exchangeCubit);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (isAllowedExchangeAuthNavigation(
              requestUrl: request.url,
              authBaseUrl: _bbAuthUrl,
            )) {
              return NavigationDecision.navigate;
            }

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
  }

  @override
  Widget build(BuildContext context) {
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

  Future<Map<String, dynamic>> _generateApiKey() async {
    final url = '$_bbAuthUrl/api/generate-api-key';

    final result =
        await _controller.runJavaScriptReturningResult('''
        (function() {
          var xhr = new XMLHttpRequest();
          xhr.open('POST', '$url', false);
          xhr.setRequestHeader('Content-Type', 'application/json');
          xhr.withCredentials = true;
          try {
            xhr.send(JSON.stringify({ apiKeyName: 'test-key-' + new Date().getTime(), includeSellToFiatBalanceApiKey: true }));
            if (xhr.status >= 200 && xhr.status < 300) {
              try { return xhr.responseText; } catch (e) { return JSON.stringify({error: 'Credential response unavailable'}); }
            } else {
              return JSON.stringify({error: 'Credential request failed'});
            }
          } catch (e) {
            return JSON.stringify({error: 'Credential request failed'});
          }
        })();
      ''')
            as String;
    String jsonString = result;
    if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
      jsonString = jsonString
          .substring(1, jsonString.length - 1)
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', '\\');
    }
    final responseData = json.decode(jsonString) as Map<String, dynamic>;

    return responseData;
  }

  Future<void> _clearCacheAndCookies() async {
    // Only clear cookies, not cache to avoid blank screen issues
    await _cookieManager.clearCookies();
  }

  Future<void> _handleLoginError() async {
    // Clear cache and cookies and reload the controller to
    //  allow the user to try logging in again
    await _clearCacheAndCookies();
    await _controller.reload();

    if (!mounted) return;
    await BlurredDialog.show(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.loc.exchangeAuthLoginFailedTitle),
        content: Text(context.loc.exchangeAuthLoginFailedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.loc.exchangeAuthLoginFailedOkButton),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAccountAfterCredentialImport(
    ExchangeCubit exchangeCubit,
  ) async {
    if (await exchangeCubit.fetchUserSummary()) return;
    if (await exchangeCubit.fetchUserSummary()) return;

    while (mounted && !_isClosing) {
      final shouldRetry = await BlurredDialog.show<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.loc.errorGenericTitle),
          content: Text(context.loc.exchangeAccountInfoLoadErrorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.loc.closeDialogButton),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.loc.tryAgainButton),
            ),
          ],
        ),
      );

      if (shouldRetry != true || !mounted || _isClosing) return;
      if (await exchangeCubit.fetchUserSummary()) return;
    }
  }

  @override
  void dispose() {
    _isClosing = true;
    super.dispose();
  }
}
