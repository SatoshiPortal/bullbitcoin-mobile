
## bullbitcoin-mobile-v0.1.95

Various bug fixes.

### Changelog
  - Finalize psbt for coldcard broadcast
  - Various UI Fixes
  - Fixes in delete wallet
  - Patches in RBF
  - Fixes in xyzpub for legacy wallets

### Required/Known-Bugs
  - bip329
  - transaction:
    - recognize transactions to self (these currently show up as the fee amount)
  - working but buggy coldcard vdisk flow
  - tests on descriptor imports
  - electrum: 
    - sometimes electrum errors and wallet can get stuck, goto settings and 
    click save again

