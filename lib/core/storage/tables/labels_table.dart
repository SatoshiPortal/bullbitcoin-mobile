import 'package:drift/drift.dart';

// ! /!\ modifying these constants leads to a breaking change
const swapLabelSystem = 'swaps';
const autoSwapLabelSystem = 'auto-swap';
const payjoinLabelSystem = 'payjoin';
const selfSpendLabelSystem = 'self-spend';
const exchangeBuyLabelSystem = 'exchange_buy';
const exchangeSellLabelSystem = 'exchange_sell';
const invoiceLabelSystem = 'invoice';
// Get Paid feature labels applied to the transaction an auto-sweep lands in the
// default wallet, so the swept funds read as the product that received them.
const lightningAddressLabelSystem = 'lightning-address';
const paymentPageLabelSystem = 'payment-page';
const posLabelSystem = 'point-of-sale';
const btcpayLabelSystem = 'btcpay';

enum LabelTypeColumn { tx, address, pubkey, input, output, xpub }

@DataClassName('LabelRow')
class Labels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
  TextColumn get reference => text()();
  TextColumn get type => textEnum<LabelTypeColumn>()();
  TextColumn get origin => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {label, reference},
  ];
}
