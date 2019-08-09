# ABOUT

Provide access to a subtree the of filesystem via http. Simply. Supports
- indexing a directory
- downlaoding files
- downloading the whole directory
- uploading

`webfs --root ~ --port 3030 --listen 127.0.0.1`

# DEV

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

## prepare buildserver
```
curl -sSL https://dist.crystal-lang.org/apt/setup.sh | sudo bash
sudo apt-get install crystal libz-dev libssl-dev
```
