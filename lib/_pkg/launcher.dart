import 'package:bb_mobile/_pkg/error.dart';
import 'package:url_launcher/url_launcher.dart';

class Launcher {
  Future<(bool?, Err?)> canLaunchApp(String link) async {
    try {
      final c = await canLaunchUrl(Uri.parse(link));
      return (c, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(bool?, Err?)> launchApp(String link) async {
    try {
      final can = await canLaunchUrl(Uri.parse(link));
      if (can) {
        await launchUrl(
          Uri.parse(link),
          // forceWebView: true
          // universalLinksOnly: true,
        );
      }
      return (true, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(bool?, Err?)> openInAppStore(String link) async {
    try {
      throw Exception();
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(bool?, Err?)> sentSupportEmail(
    String loggedInEmail,
    String name,
  ) async {
    try {
      throw UnimplementedError();
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
