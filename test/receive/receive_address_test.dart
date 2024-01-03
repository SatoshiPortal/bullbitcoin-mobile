import 'package:flutter_test/flutter_test.dart';

import '../__pages/home.dart';
import '../__pages/receive.dart';

Future receiveAddressSteps(WidgetTester tester) async {
  final homePage = THomePage(tester: tester);
  final receivePage = TReceivePage(tester: tester);
  await Future.delayed(const Duration(seconds: 3));
  await homePage.tapReceiveButton();
  await receivePage.checkHasAddressDisplay();
  await receivePage.checkHasQRDisplay();
}

Future receiveGenerateAddress(WidgetTester tester) async {
  final homePage = THomePage(tester: tester);
  final receivePage = TReceivePage(tester: tester);
  await Future.delayed(const Duration(seconds: 3));
  await homePage.tapReceiveButton();
  await receivePage.checkHasAddressDisplay();
  await receivePage.checkHasQRDisplay();
  final previousAddress = await receivePage.getAddressDisplayText();
  await Future.delayed(const Duration(seconds: 1));
  await receivePage.clickGenerateAddressButton();
  await receivePage.checkHasAddressDisplay();
  await receivePage.checkHasQRDisplay();
  await receivePage.checkAddressesAreNotSame(previousAddress);
}

Future receiveRequestPayment(WidgetTester tester) async {
  final homePage = THomePage(tester: tester);
  final receivePage = TReceivePage(tester: tester);
  await Future.delayed(const Duration(seconds: 3));
  await homePage.tapReceiveButton();
  await receivePage.checkHasAddressDisplay();
  await receivePage.checkHasQRDisplay();
  await receivePage.clickRequestPaymentButton();
  await receivePage.enterAmount('1');
  await receivePage.enterDescription('test123');
  await receivePage.clickSavePaymentButton();
  await receivePage.checkAddressDisplayHasText('label=test123');
  await receivePage.checkAddressDisplayHasText('amount=1');
}
