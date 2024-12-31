# Reproducible Builds

## Usage

```bash
docker build -t bull-mobile .
docker run --name bull-container bull-mobile
docker cp bull-container:/app/build/app/outputs/apk/release/app-release.apk ./
```
