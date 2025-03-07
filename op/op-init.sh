#!/bin/bash

CURRENT_DIR=$(pwd)
BBM_BIN_DIR=$CURRENT_DIR/bin

if echo "$PATH" | grep -q "$BBM_BIN_DIR"; then
    echo "Current directory is already in the PATH."
else
    echo "Adding current directory to the PATH."
    
    PATH=$BBM_BIN_DIR:$PATH
    echo "export PATH=$BBM_BIN_DIR:\$PATH" >> ~/.bashrc
fi

BBM_OP_HOME=$(pwd)

if ! grep -q "BBM_OP_HOME=" ~/.bashrc; then
    echo "export BBM_OP_HOME=$BBM_OP_HOME" >> ~/.bashrc
    echo "BBM_OP_HOME has been added to your environment variables."
else
    echo "BBM_OP_HOME is already set."
fi

echo "To finalize the setup, run 'source ~/.bashrc' or start a new shell session."
