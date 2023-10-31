
## bullbitcoin-mobile-v0.1.92

Various bug fixes.

### Changelog
  - transaction model updates - closer to finalization
  - storing built txs in wallet to be detected at broadcast
  - clean up cubit error states and fields in import and backup onBack and init 
  - fixed bugs in qr scanner
  - fixed bugs in freezing utxos
  - fixed bugs in send address (allowing cross network address to be used)
  - display coming soon for unsupported features like nfc
  - patched wallet card formatting issues
  - all android builds now in release mode signed with jks

When installing the app on your device you may get a pop-up saying Untrusted.

Click `More Info` -> `Install Anyway` 
Do not click Okay - that will lead to `App not installed`

### Required/Known-Bugs
  - does not properly parse bip21 address on send
  - bip329
  - transaction:
    - recognize transactions to self (these currently show up as the fee amount)
  - working but buggy coldcard vdisk flow
  - tests on descriptor imports
  - confirm fee estimated in fiat logic
  - electrum: 
    - sometimes electrum errors and wallet can get stuck, goto settings and 
    click save again

