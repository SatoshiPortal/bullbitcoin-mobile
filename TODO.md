# TODO

## Wire .env validation into build pipeline ([issue #1908](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/1908))

`tool/check_env.dart` runs `EnvValidator` against the `.env` file on disk and exits with a non-zero code if validation fails. It should be called before any `flutter build` or `flutter run` invocation.

Run it with:
```
fvm dart tool/check_env.dart
```

**NOTE:** [PR #1684](https://github.com/SatoshiPortal/bullbitcoin-mobile/pull/1684) changes the `makefile` and `Dockerfile` significantly. Wire this in after that PR is merged.

### makefile

Add a `check-env` target and call it from build/run targets:

```makefile
check-env:
	@fvm dart tool/check_env.dart

build: check-env
	@fvm flutter build $(filter-out $@,$(MAKECMDGOALS))

run: check-env
	@fvm flutter run $(filter-out $@,$(MAKECMDGOALS))
```

### Dockerfile

Add before the `flutter build` step:

```dockerfile
RUN fvm dart tool/check_env.dart
```
