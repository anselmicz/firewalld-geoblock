# firewalld-geoblock

Automatic deployment of geoblocking using [firewalld](https://github.com/firewalld/firewalld).

## What it does

* downloads either IPv4 or IPv6 IP ranges from [ipdeny.com](https://www.ipdeny.com/)
* creates and fills an ipset based on your country list
* creates and enables a rich rule to start dropping connections from specified address ranges

## Usage

`firewalld-geoblock` takes two sets of parameters: Internet Protocol version (4 or 6), and country codes. For example, to drop IPv4 connections from Argentina, Switzerland, North Korea and Tunisia, you would run:

```console
./firewalld-geoblock.sh 4 ar ch kp tn
```

Simple copy & paste (assuming all dependencies, like wget, firewalld, iptables, etc., are met) to block the biggest offenders (minus US):

```console
git clone https://github.com/anselmicz/firewalld-geoblock.git
cd firewalld-geoblock/
./firewalld-geoblock.sh 4 cn hk in ir jp kp kr ru sg tr tw vn
./firewalld-geoblock.sh 6 cn hk in ir jp kr ru sg tr tw vn
cd - && rm -rf firewalld-geoblock/
```
