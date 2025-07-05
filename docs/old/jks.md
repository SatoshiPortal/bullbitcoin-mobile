# JKS: Android APK Signing Key

For the entire release process documentation, visit: 

https://docs.flutter.dev/deployment/android

For more docs on signing releases, visit:

https://developer.android.com/studio/publish/app-signing#sign_release

## bullwallet.jks

The key that signs the apk released on the play store.

Signing Key:
```bash
keytool -genkey -v -keystore ~/.keys/mj.bullwallet.jks
-keyalg RSA \
-alias mj.bullwallet \
-keysize 2048 \
-validity 3650 
```

Public Certificate: (uploaded on Play Store)
```bash
keytool -export -rfc \
-keystore ~/.keys/bullwallet.jks
-alias bullwallet
-file ~/.keys/bullwallet_certificate.pem
```

In both cases we assume you have a .keys folder in your user's home directory. 
Feel free to change the path to your key.

## keys.properties

Create a `./android/key.properties`

```
storePassword=<password-from-previous-step>
keyPassword=<password-from-previous-step>
keyAlias=bullwallet
storeFile=~/bullwallet.jks
```

This file must not be checked into git.

## Add to KeePassXC

- [] Add the keyfile @ ~/bullwallet.jks and keys.properties to KeepassXC
- [] Create a backup of the .kdbx file.


