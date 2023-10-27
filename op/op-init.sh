#!/bin/bash

# Get the current directory
CURRENT_DIR=$(pwd)

# Check if the current directory is in the PATH
if echo $PATH | grep -q "$CURRENT_DIR"; then
    echo "Current directory is already in the PATH."
else
    echo "Adding current directory to the PATH."
    
    # Add the current directory to the PATH for the current session
    PATH=$CURRENT_DIR:$PATH
    
    # Update .bashrc or another relevant shell startup script to include the current directory in the PATH
    echo "export PATH=$CURRENT_DIR:\$PATH" >> ~/.bashrc

    echo "Please run 'source ~/.bashrc' or start a new shell session to apply the changes."
fi

# Define the BBM_OP_HOME environment variable based on the parent directory
BBM_OP_HOME=$(cd .. && pwd)

# Check if BBM_OP_HOME is already set in the environment
if ! grep -q "BBM_OP_HOME=" ~/.bashrc; then
    # It was not found, so add it to .bashrc
    echo "export BBM_OP_HOME=$BBM_OP_HOME" >> ~/.bashrc
    echo "BBM_OP_HOME has been added to your environment variables."
else
    echo "BBM_OP_HOME is already set."
fi

# Notify the user to restart the shell or source the profile to use the updated environment variables
echo "To finalize the setup, please run 'source ~/.bashrc' or start a new shell session."
