# Reproducible Builds (Work in Progress)

## NOTE
DOES NOT WORK ON MAC M1.
Refer to the following issues:
https://github.com/dart-lang/sdk/issues/48420

## Reference
As we develop the repro build process, reference https://github.com/signalapp/Signal-Android/tree/main/reproducible-builds and update this document.

## Dev

To inspect the container, uncomment the `CMD` line in the Dockerfile and run the following:

```bash
docker build -t bullwallet .
docker run -itd --name bbw bullwallet 
docker exec -it bbw bash
# inspect the container
```

## TL;DR

```bash
git clone https://github.com/SatoshiPortal/bullbitcoin-mobile && cd bullbitcoin-mobile

# Check out the release tag for the version you'd like to compare
git checkout v[the version number]

# Build the Docker image
cd reproducible_builds
docker build -t bullbitcoin-mobile .

# Go back up to the root of the project
cd ..

# Build using the Docker environment
docker run --rm -v $(pwd):/project -w /project bullbitcoin-mobile flutter build

# Verify the APKs
python3 apkdiff/apkdiff.py app/build/outputs/apks/project-release-unsigned.apk path/to/BullWalletFromPlay.apk
```

***
