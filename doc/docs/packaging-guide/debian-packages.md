# Creating Debian Packages

Tested with fresh install of debian 7.8 

## Preparing the environment

Clone the project:

```.shell
$ git clone git://github.com/locaweb/leela.git
$ cd leela
```

Install the dependencies:

```.shell
$ sudo apt-get install build-essential devscripts dh-exec cmake python-dev
```

## Packing libleela

Bootstrap ZeroMQ Lib:

```.shell
$ sudo ./automation/bootstrap/zeromq-bootstrap.sh deb
```

Create the package: 

```.shell
$ cd pkg
$ make libleela.debian
```

Locating the files:

```.shell
$ find dist/debian7/amd64/libleela
dist/debian7/amd64/libleela
dist/debian7/amd64/libleela/libleela_6.4.1-1.dsc
dist/debian7/amd64/libleela/libleela_6.4.1-1.tar.gz
dist/debian7/amd64/libleela/libleela-dev_6.4.1-1_amd64.deb
dist/debian7/amd64/libleela/libleela_6.4.1-1_amd64.deb
dist/debian7/amd64/libleela/libleela_6.4.1-1_amd64.changes
```

## Packing libleela-python

Create the package:

```.shell
$ cd pkg
$ make libleela.debian
```

Locating the files:

```.shell
$ find dist/debian7/amd64/libleela-python/
dist/debian7/amd64/libleela-python/
dist/debian7/amd64/libleela-python/libleela-python_6.3.0-1.dsc
dist/debian7/amd64/libleela-python/libleela-python_6.3.0-1_amd64.deb
dist/debian7/amd64/libleela-python/libleela-python_6.3.0-1.tar.gz
dist/debian7/amd64/libleela-python/libleela-python_6.3.0-1_amd64.changes
```

## Packing leela-warpdrive

Bootstrap Haskell:

```.shell
$ sudo ./automation/bootstrap/haskell-bootstrap.sh deb
```

Create the package:

```.shell
$ cd pkg
$ make leela-warpdrive.debian
```

Locating the files:
```.
$ find dist/debian7/amd64/leela-warpdrive/
dist/debian7/amd64/leela-warpdrive/
dist/debian7/amd64/leela-warpdrive/leela-warpdrive_5.11.0-3.tar.gz
dist/debian7/amd64/leela-warpdrive/leela-warpdrive_5.11.0-3.dsc
dist/debian7/amd64/leela-warpdrive/leela-warpdrive_5.11.0-3_amd64.changes
dist/debian7/amd64/leela-warpdrive/leela-warpdrive_5.11.0-3_amd64.deb
```

## Packing leela-blackbox

Bootstrap JZmq:

```.shell
$ sudo ./automation/bootstrap/jzmq-bootstrap.sh deb
```

Bootstrap Clojure:

```.shell
$ sudo ./automation/bootstrap/clojure-bootstrap.sh deb
```

Create the package:

```.shell
$ cd pkg
$ make leela-blackbox.debian
```


Locating the files:
```.shell
$ find dist/debian7/amd64/leela-blackbox/
dist/debian7/amd64/leela-blackbox/
dist/debian7/amd64/leela-blackbox/leela-blackbox_6.3.0-1_amd64.changes
dist/debian7/amd64/leela-blackbox/leela-blackbox_6.3.0-1.dsc
dist/debian7/amd64/leela-blackbox/leela-blackbox_6.3.0-1_amd64.deb
dist/debian7/amd64/leela-blackbox/leela-blackbox_6.3.0-1.tar.gz
```

## Packing leela-warpgrep

```.shell
$ cd pkg 
$ make leela-wapgrep.debian
```

```.shell
$ find dist/debian7/amd64/leela-warpgrep/
dist/debian7/amd64/leela-warpgrep/
dist/debian7/amd64/leela-warpgrep/leela-warpgrep_5.10.0-1_amd64.deb
dist/debian7/amd64/leela-warpgrep/leela-warpgrep_5.10.0-1_amd64.changes
dist/debian7/amd64/leela-warpgrep/leela-warpgrep_5.10.0-1.dsc
dist/debian7/amd64/leela-warpgrep/leela-warpgrep_5.10.0-1.tar.gz
```
