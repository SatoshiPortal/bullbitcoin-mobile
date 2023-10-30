
bullbitcoin-mobile-v0.1.91

Minor release patching deprecated 0.1.9 due to inconsistent source.

## Changelog
  - fixed amount entering UX in send
  - recover backup now enforces selecting a word from the list

## Required/Known-Bugs
  - bip329
  - transaction:
    - pending refactor to better store outputs and psbt data
    - recognize transactions to self (these currently show up as the fee amount)
  - broadcast:
    - check if transaction belongs to a wallet and verify outputs
  - working but buggy coldcard vdisk flow
  - tests on descriptor imports
  - confirm fee estimated in fiat logic
  - electrum: 
    - sometimes electrum errors and wallet can get stuck, goto settings and 
    click save again

