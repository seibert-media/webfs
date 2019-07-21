brew install pkg-config
brew install openssl
export PKG_CONFIG_PATH=/usr/local/opt/openssl/lib/pkgconfig

BUILDSERVER=159.69.89.131
scp -r ~/Projekte/webfs/* $BUILDSERVER:~
ssh $BUILDSERVER crystal build webfs.cr --release --static
ssh $BUILDSERVER ls -hal ~/webfs
scp $BUILDSERVER:~/webfs ~/Projekte/isac/bw/bundles/webfs/files
