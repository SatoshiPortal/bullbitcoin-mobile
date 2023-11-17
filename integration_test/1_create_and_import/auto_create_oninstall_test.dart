import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../_flows/switchToTestnet.dart';
import '../_pages/home.dart';

void main() {
  group('First Time Launch Wallets Tests', () {
    late THomePage homepage;
    final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    setUp(() async {
      app.main(fromTest: true);
    });

    testWidgets('Check mainnet exists and no testnet wallet cards exist', (tester) async {
      homepage = THomePage(tester: tester);

      await Future.delayed(const Duration(seconds: 3));
      final mainnetCard = homepage.mainnetCard;
      expect(mainnetCard, findsOneWidget);

      await switchToTestnetFromHomeAndReturnHome(tester);

      final testnetCard = homepage.testnetCard;
      expect(testnetCard, findsNothing);
    });

    testWidgets('test list', (_) async {
      await Future.delayed(const Duration(seconds: 3));
      final mne = [
        'flat',
        'runaway',
        'velvet',
        'dentist',
        'gorilla',
        'body',
        'random',
        'radio',
        'garbage',
        'double',
        'gorilla',
        'fence',
      ];
      // final idx = mne..indexWhere((element) => element == 'gorilla', 2);
      // final idx = idxOf(mne, 'gorilla', start: 2);
      final i = mne.indexOf('gorilla', 5);
      expect(10, i);
    });
  });
}

// int idxOf(List<String> words, String word, {int start = 0}) {
//   final wordCount = words.where((w) => w == word).length;
//   if (wordCount == 1) return words.indexOf(word);
//   final sameWordList = words.where((w) => w == word).toList();
//   final position = sameWordList.indexWhere((w) => w == word, start);
//   return words.indexOf(word, position);
// }

// int idxOf(List<String> words, String word, {int start = 0}) {
// // use forloop

//   for (var i = start; i < words.length; i++) {
//     if (words[i] == word) return i;
//   }
//   return -1;
// }
