# About Bull Bitcoin Mobile

Bull Bitcoin Mobile is a self-custodial Bitcoin and Liquid Network which offers non-custodial atomic swaps across Bitcoin, Lightning and Liquid. The wallet philosophy is to provide advanced features that give users the maximum control, while still being easy to use for beginners. Our goal is to make sure that anyone can take self-custody of their Bitcoin, even in a high fee environment. Our driving principle is to create a user experience which nudges the user into implementing best practices.

Following the cypherpunk ethods, the Bull Bitcoin Mobile wallet is fully open-source and trustless.

## Wallet basics

At launch, two wallets are generated: the Secure Bitcoin Wallet and the Instant Payments Wallet. Both wallets are created using the same mnemonic seed, so that a single backup is sufficient for both.

**Secure Bitcoin Wallet**: this is a descriptor-based Bitcoin network wallet which uses bech32 addresses.

**Instant Payments Wallet**: this is a descirptor-based Liquid network wallet which uses confidential addresses.

Both these wallets are able to send and receive Lightning Network payments via the swap provider.

## Core dependancies

- BDK: https://github.com/bitcoindevkit/bdk
- BDK-flutter: https://github.com/LtbLightning/bdk-flutter
- LWK: https://github.com/Blockstream/lwk
- LWK-dart (dart bindings: https://github.com/SatoshiPortal/lwk-dart
- Boltz-rust: https://github.com/SatoshiPortal/boltz-rust
- Boltz-dart: https://github.com/SatoshiPortal/boltz-dart

## Default external service providers

- Mempool.space API for fee estimates
- bullbitcoin.com API for fiat prices
- bull bitcoin and blockstream electrum servers for blockchain data
- boltz servers for swap providers

### General features

- Non-custodial: private keys are generated on the device, and never leave the device.
- Multiple wallets can be created. Users can switch easily from one wallet to the other on the wallet homepage.
- Walets with BIP39 passphrases can be created.
- Amounts can be viewed as Bitcoin or Sats.
- Users can enable RBF for each transaction.
- Users can send the full wallet balance (sweep a wallet).

### Network fee estimation

Unlike most wallets which rely on Bitcoin Core's smart fee estimation algorithm, Bull Bitcoin wallet fetches the network fee estimation from a Mempool instance. Default network fee can be specified in the settings and will be used for all transactions, unless specified when creating a transaction.

There are for network fee presets:
1. Fastest: aiming for next block
2. Fast: aiming for three blocks
3. Medium: aiming for 6 blocks
4. Economical: aiming for lowest fee possible without the transaction being purged from mempools

### Fee warning system

We have developped a warning system that aims to prevent the user from making uneconomical Bitcoin transactions. There are three types of warnings:
- Small utxo warning: receiving Bitcoin network utxos of less than 0.01 BTC is considered to be uneconomical. Users are prompted to use Liquid Network instead.
- High fee warning: all transactions where the network fee is over 3% of the value of the transaction trigger a warning.
- Slow payment warning: paying Lightning network invoices from a Bitcoin network wallet will require at least one on-chain confirmation, and thus this warning prevents users from accidentally paying a Lightning Network invoice from a Bitcoin network wallet expecting the payment to be instand.

### Default wallet selection

When receiving payments, the Bull Bitcoin app will select which wallet and which network is most appropriate based on the amount to be received. By default, payments under 0.01 BTC will be directed to the Instant Payments Wallet and payments over 0.01 BTC will be directed to the Secure Bitcoin Wallet. 

When sending payments, the Bull Bitcoin wallet will select the most appropriate wallet based both on the amount to be sent, and the network used by the recipients. 
We try to always use a wallet that is the same network as the recipient: if recipient is on-chain, use secure Bitcoin wallet and if recipient is Liquid use Instant Payments Wallet. If the recipient is Lightning, use the instant payments wallet.

Automated selection of the wallet can be overriden by the user at any time. This will most likely trigger a warning that the user can choose to ignore.

### Wallet securiy

- An optional pin from 4 to 8 digits can be set for access to the app.
- The PIN is optional to prevent users from being accidentally locked out of a wallet without having first performed a backup.
- Private keys are stored in secure storage and only accessed via the applicatiom when signing transactions, viewing the wallet’s private keys for back-up (mnemonic or xpriv). This prevents malicious applications from accessing the private keys. 
- BIP39 passphrase is also stored in secure storage, and can be viewed only via the application.
- When initializing the app, a single-sig hot wallet wallet is created. By default, this wallet does not have a BIP39 passphrase.
- A warning is displayed until the user has tested his backup by successfully entering his mnemonic.

### Hardware wallets and watch-only wallets

- Users can import watch-only wallets via QR code, copy-pasting an Xpub/Ypub/Zpub, uploading a Coldcard file or via NFC (for Coldcard).
- Users can create PSBTs from watch-only wallets for offline signing.
- Users can broadcast PSBTs signed in an offline wallet.

### Privacy and utxo management (coin selection)

- Users can create labels for receiving addresses. Transactions sent to a receiving address that has a label will inherit the label of the receiving address.
- Users can label outbound transactions. The change address of these transactions will inherit the label of the outbound transaction.
- Coin selection: users can select which utxos will be spent for each transaction. The UTXOs will have the labels of the transactions that created them. When enabling coin selection, only the selected utxos will be used to create a transaction.
- Labels can be imported and exported according to the BIP-329 standard.
- Users can connect to their own electrum server.
- The default electrum server of Bull Bitcoin does not keep logs. The secondary default electrum server of Blockstream is also believed not to keep logs.
- Users can free a specific UTXO. It will be added to a list of unspendable utxos, and will never be used when making transcations unless specific overried. Unfreezing a utxo will make the utxo spendable again.
- Combination of "send full amount" and "coin selection": a user can specific a utxo and spend that utxo's entire balance. The network fee will be deducted from the amount sent. This prevents the creation of any change output when moving a utxo from one wallet to another.

## Planned integration with the Bull Bitcoin exchange 

Our mission is to facilitate and encourage the self-custody of Bitcoin by providing an integrated experience that combines a Bitcoin Wallet, Bitcoin Payments service and a Bitcoin Exchange (on-ramp, off-ramp). For this reason, the wallet will be fully integrated with the Bull Bitcoin API. Users will be able to manage their Bull Bitcoin accounts, buy Bitcoin and sell Bitcoin. This integration will be fully open-source. Use of the Bull Bitcoin exchange is fully optional. Users do not need to register for a Bull Bitcoin account to use all wallet features.

Non-custodial Bitcoin exchanges and payment processors such as Bull Bitcoin have existed for over a decade. When a user purchases Bitcoin, the user must first provide a Bitcoin address to the exchange. The exchange will send the Bitcoin directly to the user’s own Bitcoin wallet as soon as the Bitcoin purchase is confirmed.

The primary issue with non-custodial exchanges is that they require users to set-up a Bitcoin Wallet using a separate mobile, desktop or web app before being able to purchase Bitcoin. This creates a sub-optimal and confusing user experience, forcing the end-user to use two separate applications, sharing data (bitcoin addresses) back-and-forth between the two.  Custodial exchanges provide a cleaner and more friendly user experience by providing a Bitcoin balance, a fiat balance, and a mechanism to move funds from a fiat balance to a Bitcoin balance within the same user interface. Bull Bitcoin Mobile solves the problem of having a single, integrated experience within a single mobile application without requiring the user to give up self-custody.

When installing the Bull Bitcoin Mobile app, a self-custodial wallet will be created, regardless of whether he is a Bull Bitcoin user or not. The user will access the Bull Bitcoin exchange from the same application. When purchasing Bitcoin, the mobile app will automatically create a Bitcoin receiving address and provide it to Bull Bitcoin’s servers as a new payout address and Bull Bitcoin will send the Bitcoin directly to the mobile wallet. There is no need to share the xpub of the wallet to Bull Bitcoin’s servers. Users of Bull Bitcoin Mobile can also specify an external Bitcoin address, they do not need to use the Bull Bitcoin wallet. 

When spending or selling Bitcoin, the exchange will create a payment invoice (BIP21) that will automatically be opened by the same application. All the user has to do is to confirm or reject that transaction. The experience will be functionally the same as that of a custodial exchange, with the exception that the user will have to do a backup of the Bitcoin wallet.

## Current roadmap

Suggestion to this roadmap can be proposed as Github issues.

- [ ] Bumping replace-by-fee transactions
- [ ] Re-implement smarter coin selection and labelling
- [ ] One mnemonic: new wallets are always creates either as BIP39 passphrase
- [ ] Good UX/UI for creating PSBT from watch-only wallets
- [ ] Good UX/UI for decoding and broadcasting PSBTs
- [ ] Better UX/UI for importing watch-only wallets
- [ ] Integration of Coinkite's BBQR library to export public keys, export PSBTs and import PSBTs
- [ ] Bitcoin <> Liquid network swaps (depends on Boltz backend update)
- [ ] Integrate a client-side passphrase strengh estimator
- [ ] Encrypted cloud backups connected to a key server, similar to photon-sdk
- [ ] Store persistent encrypted wallet backup on device
- [ ] Biometric authentification
- [ ] Show fiat value of transactions at the approximated time they were made
- [ ] Spanish and French translactions
- [ ] Payjoin integration
- [ ] Integrate Bull Bitcoin Fee multiple
- [ ] Auto-consolidation mode for spend
- [ ] Small utxo warning and consolidation suggestions
- [ ] Configurable mempool explorer URLs
- [ ] Configurable swap provider (similar to Electrum server)

## Acknowledgements 

- The project is entirely financed by bullbitcoin.com 
- Created by Francis Pouliot and Vishal Menon
- Main developpers: Vishal, Morteza and Sai
- Thanks to Raj for his work on on Boltz-rust
- Thanks to the BDK team: BitcoinZavior and ThunderBiscuit
- Eternal grattitude to the Boltz team Michael and Killian
- Thanks to Riccardo and the LWK team
- Thanks to Blockstream for developping the Liquid Network 

![image](https://github.com/BullishNode/bullbitcoin-mobile/assets/75800272/a61e4ccc-897d-410f-b97b-37a7c2b240cb)

