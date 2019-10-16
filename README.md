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
cd webfs
crystal webfs -- --root ~ --listen 127.0.0.1 --port 3030
```

## macos
```
brew install pkg-config
brew install openssl
export PKG_CONFIG_PATH=/usr/local/opt/openssl/lib/pkgconfig
```

## build release
```
BUILDSERVER=159.69.89.131
scp -r ~/Projekte/webfs/* $BUILDSERVER:~
ssh $BUILDSERVER crystal build webfs.cr --release --static
ssh $BUILDSERVER ls -hal webfs
scp $BUILDSERVER:~/webfs ~/Projekte/isac/bw/bundles/webfs/files
```

## prepare ubuntu 18.04 buildserver
```
curl -sSL https://dist.crystal-lang.org/apt/setup.sh | sudo bash
sudo apt-get install crystal libz-dev libssl-dev
```
