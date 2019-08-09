# macos
brew install pkg-config
brew install openssl
export PKG_CONFIG_PATH=/usr/local/opt/openssl/lib/pkgconfig

# build
BUILDSERVER=159.69.89.131
scp -r ~/Projekte/webfs/* $BUILDSERVER:~
ssh $BUILDSERVER crystal build webfs.cr --release --static
ssh $BUILDSERVER ls -hal webfs
scp $BUILDSERVER:~/webfs ~/Projekte/isac/bw/bundles/webfs/files

## prepare
curl -sSL https://dist.crystal-lang.org/apt/setup.sh | sudo bash
sudo apt-get install crystal libz-dev libssl-dev
