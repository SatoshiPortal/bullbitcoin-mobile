import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:flutter_test/flutter_test.dart';

class TReceivePage {
  TReceivePage({required this.tester});

  final WidgetTester tester;

  Finder get qrDisplay => find.byKey(UIKeys.receiveQRDisplay);
  Finder get addressDisplay => find.byKey(UIKeys.receiveAddressDisplay);
  Finder get generateAddressButton => find.byKey(UIKeys.receiveGenerateAddressButton);
  Finder get requestPaymentButton => find.byKey(UIKeys.receiveRequestPaymentButton);
  Finder get amountField => find.byKey(UIKeys.receiveAmountField);
  Finder get descriptionField => find.byKey(UIKeys.receiveDescriptionField);
  Finder get savePaymentButton => find.byKey(UIKeys.receiveSavePaymentButton);

  Future checkHasQRDisplay() async {
    print('checkHasQRDisplay');
    expect(qrDisplay, findsNWidgets(1));
  }

  Future checkHasAddressDisplay() async {
    print('checkHasAddressDisplay');
    expect(addressDisplay, findsNWidgets(1));
  }

  Future clickGenerateAddressButton() async {
    print('clickGenerateAddressButton');
    await tester.tap(generateAddressButton);
    await tester.pumpAndSettle();
  }

  Future clickRequestPaymentButton() async {
    print('clickRequestPaymentButton');
    await tester.tap(requestPaymentButton);
    await tester.pumpAndSettle();
  }

  Future enterAmount(String amount) async {
    print('enterAmount');
    await tester.enterText(amountField, amount);
    await tester.pumpAndSettle();
  }

  Future enterDescription(String description) async {
    print('enterDescription');
    await tester.enterText(descriptionField, description);
    await tester.pumpAndSettle();
  }

  Future clickSavePaymentButton() async {
    print('clickSavePaymentButton');
    await tester.tap(savePaymentButton);
    await tester.pumpAndSettle();
  }
}
