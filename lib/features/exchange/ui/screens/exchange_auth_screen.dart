import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class ExchangeAuthScreen extends StatefulWidget {
  const ExchangeAuthScreen({super.key});

  @override
  State<ExchangeAuthScreen> createState() => _ExchangeAuthScreenState();
}

class _ExchangeAuthScreenState extends State<ExchangeAuthScreen> {
  late final WebViewController _controller = WebViewController();
  late final WebviewCookieManager _cookieManager = WebviewCookieManager();
  late final String _bbAuthUrl;
  bool _isGeneratingApiKey = false;

  @override
  void initState() {
    super.initState();

    final isTestnet =
        context.read<SettingsCubit>().state.environment == Environment.testnet;
    _bbAuthUrl =
        isTestnet
            ? ApiServiceConstants.bbAuthTestUrl
            : ApiServiceConstants.bbAuthUrl;

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) async {
            final url = change.url;
            if (url == null) return;
            log.info('Url change to ${change.url}');

            // Check if the URL contains the bb_session cookie
            final bbSessionCookie = await _tryGetBBSessionCookie(change.url!);
            // If no bb_session cookie is found, do nothing as the user is not
            //  logged in yet.
            if (bbSessionCookie == null) return;

            // If the bb_session cookie is found, the user is logged in and
            //  we can proceed to try to generate and save the API key.
            log.info('Found bb_session cookie: $bbSessionCookie');

            try {
              // Set the flag to indicate that we are generating the API key
              setState(() => _isGeneratingApiKey = true);

              final apiKeyData = await _generateApiKey();
              log.info('Generated API key: $apiKeyData');
              if (apiKeyData['error'] != null) {
                setState(() => _isGeneratingApiKey = false);

                return;
              }
              // Save the API key so it can be used for future requests
              if (!mounted) return;
              await context.read<ExchangeCubit>().storeApiKey(apiKeyData);

              // Check if the API key was successfully stored
              if (!mounted) return;
              final saveApiKeyException =
                  context.read<ExchangeCubit>().state.saveApiKeyException;
              if (saveApiKeyException != null) {
                throw saveApiKeyException;
              }
            } catch (e) {
              log.severe('Error generating or saving API key: $e');
              await _handleLoginError();
            } finally {
              // Reset the flag after the API key generation process is done
              //  and if the widget is still mounted.
              if (mounted) {
                setState(() => _isGeneratingApiKey = false);
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://accounts')) {
              log.info('allowing navigation to ${request.url}');
              return NavigationDecision.navigate;
            }

            log.info('blocking navigation to ${request.url}');
            return NavigationDecision.prevent;
          },
          onHttpAuthRequest: (HttpAuthRequest request) {
            log.info(
              'HTTP Auth request for ${request.host} with realm ${request.realm}',
            );
            request.onProceed(
              WebViewCredential(
                user: dotenv.env['BASIC_AUTH_USERNAME'] ?? '',
                password: dotenv.env['BASIC_AUTH_PASSWORD'] ?? '',
              ),
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
      child:
          _isGeneratingApiKey
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
    await Future.wait([
      _controller.clearCache(),
      _controller.clearLocalStorage(),
      _cookieManager.clearCookies(),
    ]);
  }

  Future<void> _handleLoginError() async {
    // Clear cache and cookies and reload the controller to
    //  allow the user to try logging in again
    await _clearCacheAndCookies();
    await _controller.reload();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Login Failed'),
            content: const Text(
              'An error occurred, please try logging in again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
