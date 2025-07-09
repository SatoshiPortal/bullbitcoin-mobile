# PGP: Signing Git Commits & Releases

## Creating and Maintaining a PGP Key

```bash
gpg --default-new-key-algo rsa4096 --gen-key

gpg --list-secret-keys --keyid-format=long

gpg --armor --export 3AA5C34371567BD2

gpg --export-secret-key -a mj > ~/.bullwallet.gpg

gpg --import ~/.bullwallet.gpg
```
## Add to KeePassXC

- [] Add the keyfile @ ~/bullwallet.jks and keys.properties to KeepassXC
- [] Create a backup of the .kdbx file.

## Signing Release SHA256 CHECKSUMS

```bash
find . -type f -not -name "*.SHA256*" -print0 | xargs -0 -I{} -P"$(nproc)" sha256sum -b "{}" >HASHSUMS.SHA256
gpg --sign --detach-sign --armor HASHSUMS.SHA256
gpg --verify HASHSUMS.SHA256.asc
sha256sum --ignore-missing --check HASHSUMS.SHA256
```