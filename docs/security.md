# Security Documentation

## Key Generation 
The wallet must use the best source of entropy available with the host device to generate cryptographically strong keys. Requires review of bdk-flutter to know the exact spec we currently use.

## Wallet Creation 
the wallet must build descriptors correctly to ensure that funds are being received into the correct wallet which must be importable into another wallet where funds can be recovered. Watch only wallets must take extra precautions to ensure that descriptors for the correct signer is being created.

## Sensitive Key Storage 
Secure Storage is used for all sensitive key data (loss of which constitutes loss of security) which is never to be stored in Local Storage. Sensitive data lifetime in memory is controlled by ensuring that cubits where sensitive data is stored implements a clearSensitive() function that ensures that sensitive data does not persist in memory for long after use.

## Private Data Storage 
App data (loss of which constitutes loss of privacy) is stored in Local Storage using HiveDB. Hive encrypts data at rest, so even an app with privileged access across the OS like a malicious File Manager, it will only ever get encrypted data.

## Clipboard Hijacking (pending) 
A possible attack on a wallet is a malicious address fed into the clipboard while a user is pasting an address to send to. Not sure if there is anything we can do but it requires discussion.

## PSBT File Hijacking (pending) 
When watchers build transactions for the signer, it is possible that the PSBT file gets hijacked and altered in transit and that even the signer unknowingly signs an intercepted PSBT. The wallet must maintain the states of all PSBT, built and broadcasted and perform checks to ensure they haven't been tampered with. Currently this is not implemented. We just show the decoded PSBT data and ask the user to confirm.

## Code Indications 
the codebase has explicit folders and comments that identify sensitive classes, functions and variables to help with tracking of changes in these files and their dependents and also enable easier security audits. 

## Audit 
we should get some external party to review the code prior to release

## Signed Releases 
every release candidate must include signed hashes with the maintainers GPG key.

## Code Maintainer Key Management 
good key management practices around all github keys and application release keys. To ensure malicious commits do not get into the repo all commits must be signed. Prefer using SSH Access over Username & Password and enable 2FA for Github/Play/Apple.
Just in the past two years we have seen some professional Bitcoin projects being subject to attacks via a compromised key of a maintainer.

### KeyPassXC 
is a cross platform Key Manager tool. Its an old foss tank of an app and might not have the prettiest UI but from my limited research and extensive use, its a solid, no-bullshit key management tool. It uses a master encryption key (write down/memorize a 12 word seed for it) and creates an encrypted .kdbx file which is easy to backup to a pendrive. You can store everything from passwords, 2fa codes, PGP keys, SSH keys etc.