# About BULL Wallet

BULL Wallet is a self-custodial Bitcoin and Liquid Network wallet which offers non-custodial atomic swaps across Bitcoin, Lightning and Liquid. The wallet philosophy is to provide advanced features that give users the maximum control, while still being easy to use for beginners. Our goal is to make sure that anyone can take self-custody of their Bitcoin, even in a high fee environment. Our driving principle is to create a user experience which nudges the user into implementing best practices.

Following the cypherpunk ethos, the BULL Wallet is fully open-source and trustless.

## Wallet basics

During setup, BULL creates two default wallets that share the same mnemonic:

- **Secure Bitcoin Wallet**: a Bitcoin wallet using native SegWit addresses.
- **Instant Payments Wallet**: a Liquid wallet using confidential SegWit addresses.

Lightning invoices can be paid from either wallet; incoming Lightning payments are received into the Instant Payments Wallet. These payments and Bitcoin/Liquid transfers use the [configured swap service](lib/core/utils/constants.dart).

## Features

- Create, import and switch between multiple Bitcoin and Liquid wallets, including wallets with BIP39 passphrases.
- View amounts in BTC, sats or your preferred fiat currency.
- Send and receive Lightning payments through swap services, including payments to LNURL-pay requests and Lightning addresses.
- Transfer between Bitcoin and Liquid, including external wallet destinations.
- Configure automatic transfers of excess funds from the default Liquid wallet to a Bitcoin wallet, with balance and fee limits.
- Export wallet transaction history as CSV.

### Transaction fees

Bitcoin fee estimates are fetched from a mempool instance, with three presets (Fastest, Economic and Slow) and a custom fee option. Use replace-by-fee (RBF) to increase fees on eligible unconfirmed Bitcoin transactions. Warnings highlight high fees and potentially slow Bitcoin-funded Lightning payments.

## Wallet security

- Protect access to the app with an optional 4-to-8-digit PIN.
- Private keys and BIP39 passphrases are stored in secure storage on the device.
- Back up recovery phrases manually, or save an encrypted RecoverBull vault of the default mnemonic to Google Drive or a file.
- Sensitive mnemonic screens have screen-capture protection enabled by default; phrase entry uses an in-app keyboard.

RecoverBull stores the encrypted vault separately from its password-encrypted vault key, which is kept on a key server accessed over Tor.

### Hardware wallets and watch-only wallets

- Import watch-only wallets using QR codes or extended public keys (xpub/ypub/zpub).
- Connect supported Ledger and BitBox devices directly via USB or Bluetooth, depending on the device and platform.
- Create partially signed Bitcoin transactions (PSBTs) for external signing, then import and broadcast signed transactions. QR-based workflows support Coldcard, Jade, Passport, Keystone, SeedSigner, Specter and Krux; supported Coldcard models also offer NFC.

### Privacy and UTXO management (coin selection)

- Label addresses and transactions, and import or export labels using BIP-329.
- Select the UTXOs to spend or freeze coins to exclude them from automatic selection.
- Send the full wallet balance or sweep selected UTXOs, deducting fees from the amount sent.
- Use Payjoin v2 for Bitcoin payments and supported exchange interactions.
- Connect to custom Electrum servers, including `.onion` servers through embedded Tor or a local SOCKS5 proxy. RecoverBull key-server connections also use Tor.

## Integration with the Bull Bitcoin exchange

Our mission is to facilitate and encourage the self-custody of Bitcoin by providing an integrated experience that combines a Bitcoin Wallet, Bitcoin Payments service and a Bitcoin Exchange (on-ramp, off-ramp). For this reason, the wallet will be fully integrated with the Bull Bitcoin API. Users will be able to manage their Bull Bitcoin accounts, buy Bitcoin and sell Bitcoin. This integration will be fully open-source. Use of the Bull Bitcoin exchange is fully optional. Users do not need to register for a Bull Bitcoin account to use all wallet features.

Non-custodial Bitcoin exchanges and payment processors such as Bull Bitcoin have existed for over a decade. When a user purchases Bitcoin, the user must first provide a Bitcoin address to the exchange. The exchange will send the Bitcoin directly to the user’s own Bitcoin wallet as soon as the Bitcoin purchase is confirmed.

The primary issue with non-custodial exchanges is that they require users to set up a Bitcoin Wallet using a separate mobile, desktop or web app before being able to purchase Bitcoin. This creates a sub-optimal and confusing user experience, forcing the end-user to use two separate applications, sharing data (bitcoin addresses) back-and-forth between the two.  Custodial exchanges provide a cleaner and more friendly user experience by providing a Bitcoin balance, a fiat balance, and a mechanism to move funds from a fiat balance to a Bitcoin balance within the same user interface. BULL Wallet solves the problem of having a single, integrated experience within a single mobile application without requiring the user to give up self-custody.

When installing the BULL Wallet app, a self-custodial wallet will be created, regardless of whether the user is a Bull Bitcoin user or not. The user will access the Bull Bitcoin exchange from the same application. When purchasing Bitcoin, the mobile app will automatically create a Bitcoin receiving address and provide it to Bull Bitcoin’s servers as a new payout address and Bull Bitcoin will send the Bitcoin directly to the mobile wallet. There is no need to share the xpub of the wallet to Bull Bitcoin’s servers. Users of BULL Wallet can also specify an external Bitcoin address, they do not need to use the Bull Bitcoin wallet. 

When spending or selling Bitcoin, the exchange will create a payment invoice (BIP21) that will automatically be opened by the same application. All the user has to do is to confirm or reject that transaction. The experience will be functionally the same as that of a custodial exchange, with the exception that the user will have to do a backup of the Bitcoin wallet.

## Roadmap

Development is tracked in [GitHub issues](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues). To suggest a feature or report a bug, see the [contribution guidelines](CONTRIBUTING.md).

## Technical resources

- [Architecture](ARCHITECTURE.md) and [feature dependencies](FEATURES.md).
- [Toolchain, setup and development conventions](AGENTS.md). Start with an issue before implementation work; see [CONTRIBUTING.md](CONTRIBUTING.md).
- Translations are AI-generated and community-reviewed. See the [translation tooling guide](tools/README.md) for changes to [`localization/`](localization/).
- [Dependencies](pubspec.yaml) and [default service providers](lib/core/utils/constants.dart).
- [Android reproducible build and verification instructions](reproducibility/) and [BULL Wallet on WalletScrutiny](https://walletscrutiny.com/mobile/com.bullbitcoin.mobile/).
- Report vulnerabilities privately using the [security policy](SECURITY.md).
- Licensed under [MIT](LICENSE).
- [AI-generated code documentation on DeepWiki](https://deepwiki.com/SatoshiPortal/bullbitcoin-mobile).

## Acknowledgements

- Fully funded by [Bull Bitcoin](https://bullbitcoin.com)
- Created by Francis Pouliot and Vishal Menon
- Maintainers: [i5hi](https://github.com/i5hi), [ethicnology](https://github.com/ethicnology)
- Collaborators: [mocodesmo](https://github.com/mocodesmo), [kiranmetri](https://github.com/kiranmetri), [thibistaken](https://github.com/thibistaken), [basantagoswami](https://github.com/basantagoswami), [wired-pasteque](https://github.com/wired-pasteque)
- Thanks to all [contributors](https://github.com/SatoshiPortal/bullbitcoin-mobile/graphs/contributors)
- Thanks to Raj for his work on Boltz-rust
- Thanks to the BDK team: BitcoinZavior and ThunderBiscuit
- Eternal gratitude to the Boltz team Michael and Killian
- Thanks to Riccardo and the LWK team
- Thanks to Blockstream for developing the Liquid Network 

![image](https://github.com/BullishNode/bullbitcoin-mobile/assets/75800272/a61e4ccc-897d-410f-b97b-37a7c2b240cb)
