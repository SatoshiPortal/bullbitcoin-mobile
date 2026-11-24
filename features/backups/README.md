# Backups

## Dependencies

- `bull_recoverbull` supplies typed vault navigation, encrypted-backup verification and backup facts. `secrets` supplies the default Bitcoin wallet for the selected environment.
- `physical_backup_verification` verifies the mnemonic and passphrase before Backups records completion for the verified secret through RecoverBull.
