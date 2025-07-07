# Refactor Send Cubit

The send cubit is currently very messy due to the fact that the flow can change a lot based on user input and state.
As a result we have a lot of if else blocks to check for various states (primarily wallet balances (relative to amount) and input format)
and accordingly divert the flow. This has to be checked at every step of the flow to ensure we are continuing on the right track.

Below is an explaination of the expected flow / user story for the send flow and based on this understanding we can
improve the send cubit and make it easier to understand and extend and also make it more predictable.

## Send Process

There are a range of possible flows that can take place in Send, which are listed here with their enum values:

### Standard On-chain Bitcoin Transaction
BitcoinOnchain
### Payjoin On-chain Bitcoin Transaction
BitcoinOnchainPayjoin
### Standard On-chain Liquid Transaction
LiquidOnchain
### Lightning Swap via Liquid
LbtcLn
### Lightning Swap via Bitcoin
BtcLn
### Chain swap
BtcLbtcChain: Sending to a liquid address from a bitcoin wallet
LbtcBtcChain: Sending to a bitcoin address from a liquid wallet

The output process is selected based on:

- Payment Request

The selected wallet is based on the network of the Payment Request. Lightning network payments default to using the default Liquid
Wallet and only use Bitcoin if the Liquid wallet does not have balance.


- Wallet balance

When a user attempts a send; we first try to use a wallet that matches the network of the payment request.
For lightning, we always try to use the default Liquid wallet (note: the app only supports a single default liquid wallet).
If the network matched wallet has funds available, we opt for this wallet, if not, we chose whichever wallet has funds available.

We always try to network match default wallets first. If the default wallets do not have balance we chose the wallet
that has the next closest balance - not the wallet with the highest balance.

This wallet selection will be dynamically updated as the user enters an amount on the Amount page. In case the Payment
Request is an invoice with an amount; we chose the wallet on the Payment Request page and skip the Amount page.

Note: we should only use `words` WalletType for send.

## Pages

### Payment Request
If an amount is present in the Payment Request Page; we perform wallet selection here, finalize the Send Process
and skip the amount page.

Payment Requests are linked to a specific network; they can either be Bitcoin, Liquid or Lightning.

These are all the possible supported Payment Requests:

### Standard Bitcoin Address
A bitcoin address without any additional parameters.

Always requires navigating to the Amount page.

### Standard Liquid Address
A liquid address without any additional parameters.

Always requires navigating to the Amount page.

### BIP21 Bitcoin Invoice
A bitcoin invoice that may or may not have the following additional parameters:

- amount
- label
- payjoin request parameters

Requires navigating to the Amount page ONLY if an amount is not present.

If amount is present, the selectedWallet should be the default bitcoin wallet, or another bitcoin wallet
that has sufficient balance. If no bitcoin wallet has balance, the default liquid wallet will be used and the Send Process
will be a Chain Swap. If no wallets have balance, we error saying insufficient balance.

### BIP21 Liquid Invoice
A bitcoin invoice that may or may not have the following additional parameters:

- amount
- label
- assetId

Requires navigating to the Amount page ONLY if an amount is not present.

If amount is present, the selectedWallet should be the default liquid wallet. If no liquid wallet has balance,
the default bitcoin wallet or another bitcoin wallet with balance will be used and the Send Process will be a Chain Swap.
If no wallets have balance, we error saying insufficient balance.



### Bitcoin Payjoin Request
A bitcoin bip21 invoice that contains payjoin parameters. It may or may not contain an amount.

Requires navigating to the Amount page ONLY if an amount is not present.

Must always only attempt to use bitcoin wallets. Never fall back to a Liquid wallet that can trigger a chain swap.
If no bitcoin wallets have balance, we error saying insufficient balance.

### Bolt11 Lightning Invoice
A lightning invoice that generally has an amount but in rare cases may not have an amount.

Requires navigating to the Amount page ONLY if an amount is not present.

If amount is present, the selectedWallet should be the default liquid wallet and Send Process will be a LnSendSwap via Liquid.
If no liquid wallet has balance, the default bitcoin wallet or another bitcoin wallet with balance will be used
and the Send Process will be a LnSendSwap via Bitcoin.
If no wallets have balance, we error saying insufficient balance.

If magicBip21 exists in the decoded invoice, we should opt for a onchain transaction (not a lightning swap) on liquid using the liquid default wallet. if the default liquid wallet does not have the funds, we should opt for a btcToLbtcChainSwap using one of the bitcoin wallets which has balance.

### Lightning Address
A lightning address that does not contain an amount.

Always requires navigating to the Amount page.

### Amount
If an amount IS NOT present in the Payment Request Page; we move to the Amount page and perform wallet selection as
the user updates the amount. On confirming the amount, the selected wallet is finalized and the Send Process is finalized.

### Configure & Confirm
No wallet selection update or Send Process update is made on this page. Here users can configure a few Transaction
parameters for bitcoin network only:

- selected miner fees
- selected utxos
- toggling rbf

Any updates to the configuration will result in rebuilding the transaction to update the transaction data that the user must confirm.

### Progress

Based on the Send Process, we navigate to different progress screens.
