# ABOUT

Provide access to a subtree of the filesystem via http. Simply. Supports
- indexing a directory
- downloading files
- downloading zipped directories
- uploading
- optional parameters (defaults below)

`webfs --root ~ --listen 127.0.0.1 --port 3030`

# DEV

Install crystal-lang (https://crystal-lang.org/) and checkout the repo.

```
crystal run webfs.cr -- --root . --listen 127.0.0.1 --port 3030
```

## build on debian
```
curl -sSL https://dist.crystal-lang.org/apt/setup.sh | sudo bash
sudo apt-get install crystal libz-dev libssl-dev
```

## build on mac
```
brew install pkg-config openssl crystal
export PKG_CONFIG_PATH=/usr/local/opt/openssl/lib/pkgconfig
```

## build release
```
crystal build webfs.cr --release --static
```
