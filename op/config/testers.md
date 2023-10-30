# testing guidelines

This document contains guidelines for testers that will help the development team effectively patch issues.

# device specifications

Keep note of the following specs:

- device model
- os version

# reporting issues

Use the Telegram channel as the entrypoint for bringing up an issue. Someone from the team 
will review it and make an entry at:

https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/new


You can also directly make an issue yourself. 

Ideal structure for issues:

- 1: Device specifications & bug/feature description.

- 2: Provide steps to, reproduce the bug or implement the feature. If you are on testnet, screen captures in video are ideal. If you are on mainnet, add bullet points of steps to follow. Ensure to provide as much context as possible and retrace as many steps as you can.

- 3: Possible causes/solutions (optional)


## application specifications

Below are a few terms that will help testers communicate better with the development team on exactly their issue is concerned with. 

The app currently has 3 top level modules, all having their entry point UI elements on the homescreen.

### keys

This is how keys are imported or created within the app. These keys are then used to create wallets.

#### UI Reference
The first among the 3 buttons in the top right corner. 

+ symbol button

This leads to importing seeds, passphrases, xpubs and descriptors.

### wallets

An individual wallet created from a key.

#### UI Reference

The main cards seen on the home page and all associated elements including Send/Recieve, Transactions & Wallet Settings. 


### settings

Global app settings common across all wallets.

#### UI Reference
The second among the 3 buttons in the top right corner. 

`gear` symbol button

This section allows you to change units, currency, default fee rate, node-address, broadcast transactions etc.



