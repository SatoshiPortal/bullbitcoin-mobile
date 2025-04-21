import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bb_mobile/core/exchange/domain/usecases/save_api_key_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class ExchangeCubit extends Cubit<ExchangeState> {
  ExchangeCubit({
    required SaveApiKeyUsecase saveApiKeyUsecase,
  })  : _saveApiKeyUsecase = saveApiKeyUsecase,
        super(const ExchangeState()) {
    initController();
    loadUrlWithBasicAuth();
  }

  late final WebViewController webViewController;
  Timer? _cookieCheckTimer;
  final bool _webViewInitialized = false;
  String? _previousUrl;

  final SaveApiKeyUsecase _saveApiKeyUsecase;
  final String targetAuthCookie = 'bb_session';
  final String baseUrl = ApiServiceConstants.bbAuthUrl;

  final List<String> _ignoredCookies = [
    'i18n',
    'i18n-lng',
    'i18next',
    'django_language',
    'language',
    'locale',
    'hl',
  ];

  final String _baseAccountsUrl = 'https://accounts05.bullbitcoin.dev';
  final String _loginUrlPattern = 'login';
  final String _registrationUrlPattern = 'registration';
  final String _verificationUrlPattern = 'verification';

  void initController() {
    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setLoading(true);
            _previousUrl = state.currentUrl;
            setCurrentUrl(url);
            _checkForSuccessfulLogin(url);
          },
          onPageFinished: (url) {
            setLoading(false);
            resetCookieCheckAttempts();
            Future.delayed(const Duration(milliseconds: 500), () {
              _checkAllCookies();
              _startCookiePolling();
            });
          },
          onUrlChange: (UrlChange change) {
            final currentUrl = change.url;
            if (currentUrl != null) {
              _previousUrl = state.currentUrl;
              setCurrentUrl(currentUrl);
              _checkAllCookies();
              _checkForSuccessfulLogin(currentUrl);
            }
          },
          onWebResourceError: (WebResourceError error) {
            setError(message: '${error.errorType}: ${error.description}');
            _stopCookiePolling();
          },
          onHttpAuthRequest: (HttpAuthRequest request) {
            request.onProceed(
              WebViewCredential(
                user: dotenv.env['BASIC_AUTH_USERNAME'] ?? '',
                password: dotenv.env['BASIC_AUTH_PASSWORD'] ?? '',
              ),
            );
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15.0 Safari/604.1',
      );

    if (Platform.isAndroid) {
      AndroidWebViewController.enableDebugging(false);
      final androidController =
          webViewController.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    } else if (Platform.isIOS) {
      final iosController =
          webViewController.platform as WebKitWebViewController;
      iosController.setAllowsBackForwardNavigationGestures(true);
    }
  }

  void setLoading(bool isLoading) {
    emit(state.copyWith(isLoading: isLoading));
  }

  void setError({bool hasError = true, String message = ''}) {
    emit(state.copyWith(
        hasError: hasError, errorMessage: message, isLoading: false));
  }

  void setCurrentUrl(String url) {
    emit(state.copyWith(currentUrl: url));
  }

  void incrementCookieCheckAttempts() {
    emit(state.copyWith(cookieCheckAttempts: state.cookieCheckAttempts + 1));
  }

  void resetCookieCheckAttempts() {
    emit(state.copyWith(cookieCheckAttempts: 0));
  }

  void setAuthenticated(bool authenticated) {
    emit(state.copyWith(authenticated: authenticated));
  }

  void updateCookies(Map<String, String> cookies) {
    emit(state.copyWith(allCookies: cookies));
  }

  void setApiKeyGenerating(bool generating) {
    emit(state.copyWith(apiKeyGenerating: generating));
  }

  void setApiKeyResponse(String response) {
    emit(state.copyWith(apiKeyResponse: response));
  }

  Future<void> storeApiKey(Map<String, dynamic> apiKeyData) async {
    try {
      debugPrint('Storing API key: $apiKeyData');
      final jsonString = state.apiKeyResponse;
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('No API key response available to store');
        return;
      }
      final success = await _saveApiKeyUsecase.execute(jsonString);
      if (success) {
        debugPrint('API key successfully stored');
      } else {
        debugPrint('Failed to store API key');
      }
    } catch (e) {
      debugPrint('Error in storeApiKey: $e');
    }
  }

  Future<void> _cookieManager() async {
    try {
      final cookieManager = WebviewCookieManager();
      final gotCookies = await cookieManager.getCookies('https://$baseUrl');
      if (gotCookies.isNotEmpty) {
        for (final cookie in gotCookies) {
          if (cookie.name == targetAuthCookie) {
            final updatedCookies = Map<String, String>.from(state.allCookies);
            updatedCookies[targetAuthCookie] = cookie.value;
            updateCookies(updatedCookies);
            setAuthenticated(true);
            _stopCookiePolling();
            return;
          }
        }
      }
      bool containsSessionToken = false;
      bool containsCsrfToken = false;
      for (final item in gotCookies) {
        if (item.name.contains('csrf')) containsCsrfToken = true;
        if (item.name == 'bb_session') containsSessionToken = true;
      }
      if (containsCsrfToken && containsSessionToken) {
        final bbxUrl = dotenv.env['BBX_URL'];
        if (bbxUrl != null && bbxUrl.isNotEmpty) {
          final Uri url = Uri.parse('https://$bbxUrl');
          webViewController.loadRequest(url);
        }
      }
    } catch (e) {
      debugPrint('Error in cookie manager: $e');
    }
  }

  void _startCookiePolling() {
    if (_cookieCheckTimer != null) return;
    _cookieCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      incrementCookieCheckAttempts();
      if (state.cookieCheckAttempts > state.maxCookieCheckAttempts) {
        _stopCookiePolling();
        return;
      }
      _checkAllCookies();
    });
  }

  void _stopCookiePolling() {
    _cookieCheckTimer?.cancel();
    _cookieCheckTimer = null;
  }

  Future<void> _checkAllCookies() async {
    if (state.authenticated) return;
    await _checkNativeCookies();
  }

  Future<bool> _checkNativeCookies() async {
    try {
      final cookieManager = WebviewCookieManager();
      final nativeCookies = await cookieManager.getCookies('https://$baseUrl');
      final Map<String, String> cookieMap = {};
      for (final cookie in nativeCookies) {
        cookieMap[cookie.name] = cookie.value;
      }
      updateCookies(cookieMap);
      for (final cookie in nativeCookies) {
        if (cookie.name == targetAuthCookie) {
          setAuthenticated(true);
          _stopCookiePolling();
          await _generateApiKey();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking native cookies: $e');
    }
    return false;
  }

  Future<void> _generateApiKey() async {
    if (state.apiKeyGenerating) return;
    setApiKeyGenerating(true);
    try {
      await webViewController
          .runJavaScript('console.log("Preparing to generate API key...");');
      await Future.delayed(const Duration(milliseconds: 500));
      final result = await webViewController.runJavaScriptReturningResult('''
        (function() {
          var xhr = new XMLHttpRequest();
          xhr.open('POST', 'https://accounts05.bullbitcoin.dev/api/generate-api-key', false);
          xhr.setRequestHeader('Content-Type', 'application/json');
          xhr.withCredentials = true;
          try {
            xhr.send(JSON.stringify({ apiKeyName: 'test-key-' + new Date().getTime() }));
            if (xhr.status >= 200 && xhr.status < 300) {
              try { return xhr.responseText; } catch (e) { return JSON.stringify({error: 'Failed to parse response: ' + e.toString()}); }
            } else {
              return JSON.stringify({ error: 'Request failed with status: ' + xhr.status, statusText: xhr.statusText || 'Unknown error' });
            }
          } catch (e) {
            return JSON.stringify({error: 'XHR Error: ' + e.toString()});
          }
        })();
      ''');
      String jsonString = result.toString();
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonString
            .substring(1, jsonString.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', '\\');
      }
      try {
        final responseData = json.decode(jsonString);
        setApiKeyResponse(jsonString);
        setApiKeyGenerating(false);
        await storeApiKey(responseData as Map<String, dynamic>);
      } catch (parseError) {
        if (jsonString.contains('apiKey')) {
          setApiKeyResponse('{"apiKeyRawResponse": $jsonString}');
          setApiKeyGenerating(false);
        } else {
          throw Exception('Invalid JSON response: $jsonString');
        }
      }
    } catch (e) {
      await _tryAlternativeApiKeyGeneration();
      setApiKeyGenerating(false);
    }
  }

  Future<void> _tryAlternativeApiKeyGeneration() async {
    try {
      await webViewController.runJavaScript('''
        (function() {
          var iframe = document.createElement('iframe');
          iframe.style.display = 'none';
          document.body.appendChild(iframe);
          var form = document.createElement('form');
          form.method = 'POST';
          form.action = 'https://accounts05.bullbitcoin.dev/api/generate-api-key';
          form.target = iframe.name;
          var input = document.createElement('input');
          input.type = 'hidden';
          input.name = 'apiKeyName';
          input.value = 'test-key-' + Date.now();
          form.appendChild(input);
          document.body.appendChild(form);
          setTimeout(function() {
            form.submit();
            setTimeout(function() {
              document.body.removeChild(form);
              document.body.removeChild(iframe);
            }, 5000);
          }, 100);
        })();
      ''');
      await Future.delayed(const Duration(seconds: 2));
      setApiKeyResponse(
          '{"info": "Alternative API request submitted. Check console logs for details."}');
    } catch (e) {
      debugPrint('Alternative API generation also failed: $e');
    }
  }

  Future<void> loadUrlWithBasicAuth() async {
    try {
      final Uri url = Uri.parse('https://$baseUrl');
      webViewController.loadRequest(url);
    } catch (e) {
      setError(message: 'Failed to load the page: $e');
    }
  }

  void _checkForSuccessfulLogin(String currentUrl) {
    if (_previousUrl == null) return;
    final wasOnAuthFlow = _previousUrl!.contains(_loginUrlPattern) ||
        _previousUrl!.contains(_registrationUrlPattern) ||
        _previousUrl!.contains(_verificationUrlPattern);
    final isOnMainPage = !currentUrl.contains(_loginUrlPattern) &&
        !currentUrl.contains(_registrationUrlPattern) &&
        !currentUrl.contains(_verificationUrlPattern);
    if (wasOnAuthFlow && isOnMainPage) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!state.authenticated) {
          await _checkAllCookies();
          await _generateApiKey();
        }
        emit(state.copyWith(showLoginSuccessDialog: true));
      });
    }
  }

  void hideLoginSuccessDialog() {
    emit(state.copyWith(showLoginSuccessDialog: false));
  }

  Future<void> checkAPIKey() async {}
  Future<void> checkUser() async {}
}
