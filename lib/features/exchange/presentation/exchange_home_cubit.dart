import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bb_mobile/core/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_home_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class ExchangeHomeCubit extends Cubit<ExchangeHomeState> {
  ExchangeHomeCubit({
    required SaveExchangeApiKeyUsecase saveExchangeApiKeyUsecase,
    required DeleteExchangeApiKeyUsecase deleteExchangeApiKeyUsecase,
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
  }) : _saveExchangeApiKeyUsecase = saveExchangeApiKeyUsecase,
       _deleteExchangeApiKeyUsecase = deleteExchangeApiKeyUsecase,
       _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       super(const ExchangeHomeState()) {
    _initController();
    _checkForAPIKeyAndLoadDetails();
  }

  final SaveExchangeApiKeyUsecase _saveExchangeApiKeyUsecase;
  // ignore: unused_field
  final DeleteExchangeApiKeyUsecase _deleteExchangeApiKeyUsecase;
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  late final WebViewController webViewController;
  Timer? _cookieCheckTimer;

  @override
  Future<void> close() {
    _cookieCheckTimer?.cancel();
    return super.close();
  }

  void _setError({bool hasError = true, String message = ''}) => emit(
    state.copyWith(hasError: hasError, errorMessage: message, isLoading: false),
  );
  void _setCurrentUrl(String currentUrl) =>
      emit(state.copyWith(currentUrl: currentUrl));
  void _setPreviousUrl(String previousUrl) =>
      emit(state.copyWith(previousUrl: previousUrl));
  void _incrementCookieCheckAttempts() =>
      emit(state.copyWith(cookieCheckAttempts: state.cookieCheckAttempts + 1));
  void _resetCookieCheckAttempts() =>
      emit(state.copyWith(cookieCheckAttempts: 0));
  void _setAuthenticated(bool authenticated) =>
      emit(state.copyWith(authenticated: authenticated));
  void _updateCookies(Map<String, String> allCookies) =>
      emit(state.copyWith(allCookies: allCookies));
  void _setApiKeyGenerating(bool apiKeyGenerating) =>
      emit(state.copyWith(apiKeyGenerating: apiKeyGenerating));
  void _setApiKeyResponse(String apiKeyResponse) =>
      emit(state.copyWith(apiKeyResponse: apiKeyResponse));

  Future<void> fetchUserSummary() async {
    emit(state.copyWith(isFetchingUserSummary: true));
    try {
      final userSummary = await _getExchangeUserSummaryUsecase.execute();
      emit(state.copyWith(userSummary: userSummary));
    } catch (e) {
      emit(state.copyWith(error: e));
    } finally {
      emit(state.copyWith(isFetchingUserSummary: false));
    }
  }

  void _initController() {
    webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                emit(state.copyWith(isLoading: true));
                _setPreviousUrl(state.currentUrl);
                _setCurrentUrl(url);
                _checkForSuccessfulLogin(url);
              },
              onPageFinished: (url) {
                emit(state.copyWith(isLoading: false));
                _resetCookieCheckAttempts();
                Future.delayed(const Duration(milliseconds: 500), () {
                  _checkAllCookies();
                  _startCookiePolling();
                });
              },
              onUrlChange: (UrlChange change) {
                final currentUrl = change.url;
                if (currentUrl != null) {
                  _setPreviousUrl(state.currentUrl);
                  _setCurrentUrl(currentUrl);
                  _checkAllCookies();
                  _checkForSuccessfulLogin(currentUrl);
                }
              },
              onWebResourceError: (WebResourceError error) {
                _setError(message: '${error.errorType}: ${error.description}');
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

  Future<void> _checkForAPIKeyAndLoadDetails() async {
    try {
      // Uncomment to delete API key for testing purposes
      // await _deleteExchangeApiKeyUsecase.execute();
      final user = await _getExchangeUserSummaryUsecase.execute();
      if (user == null) {
        // TODO: Move this to bloc listener and execute if not loading anymore and
        // no api key is found.
        final Uri url = Uri.parse('https://${state.baseUrl}');
        await webViewController.loadRequest(url);
      } else {
        emit(state.copyWith(showLoginSuccessDialog: true, userSummary: user));
        // final bbxUrl = dotenv.env['BBX_URL'];
        // final Uri url = Uri.parse('https://$bbxUrl');
        // webViewController.loadRequest(url);
        // final user = await _getUserSummaryUseCase.execute(apiKey.key);
        // if (user != null) {
        //   emit(state.copyWith(userSummary: user));
        // } else {
        //   _setError(message: 'Failed to load user summary');
        // }
      }
    } catch (e) {
      _setError(message: 'Failed to load the page: $e');
    }
  }

  Future<void> _storeApiKey(Map<String, dynamic> apiKeyData) async {
    try {
      debugPrint('Storing API key: $apiKeyData');
      final jsonString = state.apiKeyResponse;
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('No API key response available to store');
        return;
      }
      await _saveExchangeApiKeyUsecase.execute(jsonString);
      debugPrint('API key successfully stored');

      await _checkForAPIKeyAndLoadDetails();
    } catch (e) {
      debugPrint('Error in storeApiKey: $e');
    }
  }

  void _startCookiePolling() {
    if (_cookieCheckTimer != null) return;
    _cookieCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _incrementCookieCheckAttempts();
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
      final nativeCookies = await cookieManager.getCookies(
        'https://${state.baseUrl}',
      );
      final Map<String, String> cookieMap = {};
      for (final cookie in nativeCookies) {
        cookieMap[cookie.name] = cookie.value;
      }
      _updateCookies(cookieMap);
      for (final cookie in nativeCookies) {
        if (cookie.name == state.targetAuthCookie) {
          _setAuthenticated(true);
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
    _setApiKeyGenerating(true);
    try {
      await webViewController.runJavaScript(
        'console.log("Preparing to generate API key...");',
      );
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
        _setApiKeyResponse(jsonString);
        _setApiKeyGenerating(false);
        await _storeApiKey(responseData as Map<String, dynamic>);
      } catch (parseError) {
        if (jsonString.contains('apiKey')) {
          _setApiKeyResponse('{"apiKeyRawResponse": $jsonString}');
          _setApiKeyGenerating(false);
        } else {
          throw Exception('Invalid JSON response: $jsonString');
        }
      }
    } catch (e) {
      await _tryAlternativeApiKeyGeneration();
      _setApiKeyGenerating(false);
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
      _setApiKeyResponse(
        '{"info": "Alternative API request submitted. Check console logs for details."}',
      );
    } catch (e) {
      debugPrint('Alternative API generation also failed: $e');
    }
  }

  void _checkForSuccessfulLogin(String currentUrl) {
    final previousUrl = state.previousUrl;
    if (previousUrl == null) return;
    final wasOnAuthFlow =
        previousUrl.contains(state.loginUrlPattern) ||
        previousUrl.contains(state.registrationUrlPattern) ||
        previousUrl.contains(state.verificationUrlPattern);
    final isOnMainPage =
        !currentUrl.contains(state.loginUrlPattern) &&
        !currentUrl.contains(state.registrationUrlPattern) &&
        !currentUrl.contains(state.verificationUrlPattern);
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
}
