import 'package:bb_mobile/core/labels/domain/label_entity.dart';

final addresses = [
  'bc1q7cyfzrq4xm3nscpkevj8ug3u8dgxs2j4h8c9at',
  'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
  '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy',
];

final txids = [
  '5b75086daabbdb5baf8443b2430fbb12b098eaf873f9d08771a0a6f356a4ee66',
  'f4184fc596403b9d638783cf57adfe4c75c605f6356fbc91338530e9831e9e16',
  'ea44e97271691990157559d0bdd9959e02790c34db6c006d779e82fa5aee708e',
];

final labels = [
  Label(
    type: LabelType.address,
    ref: addresses[0],
    label: 'Bitcoin Purchase',
  ),
  // this duplicate should be ignored by the storage
  Label(
    type: LabelType.address,
    ref: addresses[0],
    label: 'Bitcoin Purchase',
  ),
  Label(
    type: LabelType.address,
    ref: addresses[0],
    label: 'Cold Storage',
  ),
  Label(
    type: LabelType.address,
    ref: addresses[0],
    label: 'Hardware Wallet',
    origin: 'integration_test',
  ),
  Label(
    type: LabelType.address,
    ref: addresses[1],
    label: 'Exchange Withdrawal',
    origin: 'integration_test',
  ),
  Label(
    type: LabelType.address,
    ref: addresses[2],
    label: 'Donation Address',
  ),
  Label(
    type: LabelType.tx,
    ref: txids[0],
    label: 'Bitcoin Purchase',
  ),
  Label(
    type: LabelType.tx,
    ref: txids[0],
    label: 'Investment',
  ),
  Label(
    type: LabelType.tx,
    ref: txids[0],
    label: 'Important Transaction',
  ),
  Label(
    type: LabelType.tx,
    ref: txids[1],
    label: 'Important Transaction',
  ),
  Label(
    type: LabelType.tx,
    ref: txids[2],
    label: 'Important Transaction',
  ),
];
