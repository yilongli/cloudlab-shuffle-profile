#!/bin/bash
rm -rf caladan
git clone https://github.com/yilongli/caladan.git
cd caladan

# Build submodules
if lspci | grep -q 'ConnectX-[4,5,6]'; then
    sed -ri 's,(CONFIG_MLX5=)n,\1y,' build/config
elif lspci | grep -q 'ConnectX-3'; then
    sed -ri 's,(CONFIG_MLX4=)n,\1y,' build/config
fi
make submodules

# Build kernel module ksched
make clean && make
pushd ksched
make clean && make
popd

# Build C++ bindings and the shim layer
make -C bindings/cc
make -C shim
