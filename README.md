## ⚡️ Quick start



> Make sure Flutter is installed 

> Make sure either Android Studio or Xcode is installed

> Installation docs [here](https://docs.flutter.dev/get-started/install).

> Make sure the Flutter VSCode Extension is installed


<br>
Clean the project

```bash
flutter clean
flutter pub get
```

<br>
Run via CLI

> Select device from bottom right of VSCode.
```bash
flutter run
```

<br>
Run via VSCode debugger

> Select device from bottom right of VSCode.

> Go to 'Run and Debug' panel on the Side Bar

> Select 'debug' from the dropdown

> Click the Play Button 

> Open Debug Console for logs

# About Bull Bitcoin Mobile

Bull Bitcoin Mobile has two main components: an open-source non-custodial Bitcoin wallet and a mobile interface for the Bull Bitcoin exchange and payments service offered at www.BullBitcoin.com. The app is designed to work on Android and iOS.

The Bull Bitcoin wallet can be used by anyone. Trading features and trusted features can be unlocked by logging into a Bull Bitcoin account.

The wallet is built in the dart/flutter framework using the Bitcoin Development Kit, specifically the BDK-flutter library. 

Note: Bitcoin Exchange features not yet released.

www.bullbitcoin.com

## Motivation 

Our mission is to facilitate and encourage the self-custody of Bitcoin by providing an integrated experience that combines a Bitcoin Wallet, Bitcoin Payments service and a Bitcoin Exchange (on-ramp, off-ramp).

Non-custodial Bitcoin exchanges and payment processors such as Bull Bitcoin have existed for over a decade. When a user purchases Bitcoin, the user must first provide a Bitcoin address to the exchange. The exchange will send the Bitcoin directly to the user’s own Bitcoin wallet as soon as the Bitcoin purchase is confirmed.

The primary issue with non-custodial exchanges is that they require users to set-up a Bitcoin Wallet using a separate mobile, desktop or web app before being able to purchase Bitcoin. This creates a sub-optimal and confusing user experience, forcing the end-user to use two separate applications, sharing data (bitcoin addresses) back-and-forth between the two. 

Custodial exchanges provide a cleaner and more friendly user experience by providing a Bitcoin balance, a fiat balance, and a mechanism to move funds from a fiat balance to a Bitcoin balance within the same user interface.

Bull Bitcoin Mobile solves the problem of having a single, integrated experience within a single mobile application without requiring the user to give up self-custody.

## Integration with Bull Bitcoin exchange and payment processor [planned]

When installing the Bull Bitcoin Mobile app, a self-custodial wallet will be created, regardless of whether he is a Bull Bitcoin user or not. The user will access the Bull Bitcoin exchange from the same application. When purchasing Bitcoin, the mobile app will automatically create a Bitcoin receiving address and provide it to Bull Bitcoin’s servers as a new payout address and Bull Bitcoin will send the Bitcoin directly to the mobile wallet. There is no need to share the xpub of the wallet to Bull Bitcoin’s servers.

Users of Bull Bitcoin Mobile can also specify an external Bitcoin address, they do not need to use the Bull Bitcoin wallet. 

When spending or selling Bitcoin, the exchange will create a payment invoice (BIP21) that will automatically be opened by the same application. All the user has to do is to confirm or reject that transaction. The experience will be functionally the same as that of a custodial exchange, with the exception that the user will have to do a backup of the Bitcoin wallet.

## Bitcoin wallet features

### General features

- Non-custodial: private keys are generated on the device, and never leave the device.
- Wallets are descriptor based. Users can export their wallet descriptors.
- Multiple wallets can be created. Users can switch easily from one wallet to the other on the wallet homepage.
- Amounts can be viewed as Bitcoin or Sats.
- Users can enable RBF for each transaction.
- Users can send the full wallet balance (sweep a wallet).

### Network fee estimation

- Unlike most wallets which rely on Bitcoin Core's smart fee estimation algorithm, Bull Bitcoin wallet fetches the network fee estimation from a Mempool instance.
- Network fees will be more dynamic, and much cheaper. 
- Default network fee can be specified in the settings and will be used for all transactions, unless specified when creating a transaction
- There are for network fee presets:
1. Fastest: aiming for next block
2. Fast: aiming for three blocks
3. Medium: aiming for 6 blocks
4. Economical: aiming for lowest fee possible without the transaction being purged from mempools

### Hot wallet securiy

- An optional pin from 4 to 8 digits can be set for access to the app.
- The PIN is optional to prevent users from being accidentally locked out of a wallet without having first performed a backup.
- Private keys are stored in secure storage and only accessed via the applicatiom when signing transactions, viewing the wallet’s private keys for back-up (mnemonic or xpriv). This prevents malicious applications from accessing the private keys. 
- BIP39 passphrase is also stored in secure storage, and can be viewed only via the application.
- When initializing the app, a single-sig hot wallet wallet is created. By default, this wallet does not have a BIP39 passphrase.
- Users can create additional wallets and add an optional BIP39 passphrase.
- A warning is displayed until the user has tested his backup by successfully entering his mnemonic.

### Hardware wallets and watch-only wallets

- Users can import watch-only wallets via QR code, copy-pasting an Xpub/Ypub/Zpub, uploading a Coldcard file or via NFC (for Coldcard).
- Users can create PSBTs from watch-only wallets for offline signing.
- Users can broadcast PSBTs signed in an offline wallet.

### Privacy and utxo management (coin selection)

- Users can create labels for receiving addresses. Transactions sent to a receiving address that has a label will inherit the label of the receiving address.
- Users can label outbound transactions. The change address of these transactions will inherit the label of the outbound transaction.
- Coin selection: users can select which utxos will be spent for each transaction. The UTXOs will have the labels of the transactions that created them. When enabling coin selection, only the selected utxos will be used to create a transaction.
- Users can optionally connect to their own electrum server.
- The default electrum server of Bull Bitcoin does not keep logs. The secondary default electrum server of Blockstream is also believed not to keep logs.
- Users can free a specific UTXO. It will be added to a list of unspendable utxos, and will never be used when making transcations unless specific overried. Unfreezing a utxo will make the utxo spendable again.
- Combination of "send full amount" and "coin selection": a user can specific a utxo and spend that utxo's entire balance. The network fee will be deducted from the amount sent. This prevents the creation of any change output when moving a utxo from one wallet to another.

### Roadmap

- Extract and display transaction details of a PSBT file before broadcasting.
- Wallet translation in French and Spanish.
- Store encrypted backup of wallets on the device.
- Encrypted cloud wallet backups for registered Bull Bitcoin users, with a scheme similar to photon-sdk. 
- Display passphrase and encryption password strength estimator.
- Real-time notification of inbound payments via the mempool websocket server. 
- Optional push notifications for inbound transactions and transaction confirmations.
- Integration of Payjoin Client
- Shielded transactions for registered Bull Bitcoin users [trusted swap]
- Receive Lightning Network payments with automated conversion to on-chain funds [trusted swap].
- Integration of compact blocks syncing with the Bitcoin Network, which protects users’ network privacy.
- Integration of the Lightning Network Development Kit, allowing the user to create a self-custodial Lightning Wallet.
- Integration of a Lightning Service Provider which would allow the user to seamlessly open balanced Lightning Network channels.

## Acknowledgements 

- Most of the code is by Morteza.
- Credits to i5hi for contributions and advice.
- Thanks Kexkey and BitcoinZavior for their advice.
- Big thanks to Spiral, BitcoinZavior for creating BDK-flutter, Thunderbiscuit for BDK-ffi and the BDK team for making this project possible.
- Thanks to the Electrum project for creating the backend Bitcoin network interface. 
- Thanks to the Mempool project for their fee estimation API and blockchain explorer interface.
- Thanks to the Bitcoin Core developers for the underlying node software. 
- Thanks to Blue Wallet for the inspiration for the user interface.
- This project is tested with BrowserStack.
