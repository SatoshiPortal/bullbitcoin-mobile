# operator

automated sop for working on the bullbitcoin-mobile project

## usage

add `bbm` to your PATH by adding the following to either:

- ~/.bashrc
- ~/.zshrc
- ~/.profile
- /etc/environment

```bash

echo "PATH=$PATH:$(pwd)/op/bin" >> ~/.bashrc
source ~/.bashrc
```

now you can run the `bbm` script.

all additional help can be found by using the script.

## bin

contains the entrypoint `bbm` script

`mod` folder contains 
- lib functions that offer general utility like logging, key generation, reading and writing config
- core functions called in bbm that each represent a certain operational procedure.


## config

where scripts need to create or use certain config files, they should be placed here