# boltz-dart 

The language bindings library `boltz-dart`, written for `boltz-rust`, will have a more abstracted api.

The final dart API would ideally look as follows:

### SUBMARINE SWAP - PAYING EXTERNAL LN WALLET

m/purpose/network/21/0/*

```dart

import 'package:boltz/boltz.dart';

final network = BitcoinNetwork.Mainnet;
final electrumUrl = 'electrum.bullbitcoin.com:50002'
final boltzUrl = 'api.boltz.exchange';
final index = 12;
final mnemonic = 'bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon';

// out value determined by invoice
final invoice = 'lnbc1...scanned-by-user-paying-external-ln-wallet...';

final fees = getBoltzFees(boltzUrl);

// Backup this structure
final boltzBtcLnSubmarineSwap  = BtcLnSwap.newSubmarine(
    mnemonic, 
    index,
    invoice
    network,
    electrumUrl,
    boltzUrl,
);

final paymentDetails = boltzBtcLnSubmarineSwap.paymentDetails();
// Construct local transaction to pay lockup_address from boltz with given amount
final txid = localWallet.send(paymentDetails.0, paymentDetails.1);
final status = boltzBtcLnSubmarineSwap.status();

// invoice will be paid by boltz. If not, we must refund after timeout
final address = localWallet.getNewAddress();
final absoluteFees = read.userInput();
final txid = boltzBtcLnSubmarineSwap.refund(address, absoluteFees);

```

### REVERSE SWAP - RECIEVING FROM EXTERNAL LN WALLET

m/purpose/network/42/0/*

```dart
final index = 12;
final mnemonic = 'bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon';
// explicit out value
final outValue = 100000;
final fees = getBoltzFees(boltzUrl);
final boltzBtcLnReverseSwap  = BtcLnSwap.newReverse(
    mnemonic,
    index,
    network,
    outValue,
    electrumUrl,
    boltzUrl,
);
final paymentDetails = boltzBtcLnReverseSwap.paymentDetails();
// Pay invoice provided by boltz (user is recieving a payment from an external LN wallet)
final status = boltzBtcLnReverseSwap.status();
// Construct swap transaction to claim lockup_address from boltz with given amount
// Genereate outputAddresss from local wallet
final address = localWallet.getNewAddress();
final absoluteFees = read.userInput();
final txid = boltzBtcLnReverseSwap.claim(address, fees);
```

# Build binaries on mac

```
cd rust
make all
```

All targets should be able to be built on a M1 or later macos

Linux builds will require some gcc libs

```
brew install aarch64-linux-gnu-gcc arm-linux-gnueabi-gcc arm-linux-gnueabihf-gcc i686-linux-gnu-gcc x86_64-linux-gnu-gcc

```