# Address & Tx Logic


## Init process

The wallet must first sync, load utxos, txs and last address index.

### Init addresses

Then we get and store all addresses from 0 to synced index. 

We mark them all as unset.

Some of these might be used some might not be, we will find this out using utxos and transaction
history.

Same goes for change, but change will always be used or active. We never generate unused change and display them to the user.

### Init utxos

Then we get latest utxos and update relavent addresses from unset to active.

We also add utxos to the relavant address model.

### Init txs

Then we get transaction history:

- for sends, we look for change and mark unset to used.
- for receives, we look for deposits mark unset to used.

## Updates

Updates happen when a user refreshes the home screen, or when a transaction is sent, or
when a notification over wss triggers a sync.

The sync process uses balance as a reference to know whether to update address and tx models.

If balance is updated, we first look for a new tx and a new utxo. 

We then find the associated address and update it.

We then look to see if old utxos are spent.

Sync will also check if there are always 10 available unused address for the user to cycle through, if not it will generate them.

