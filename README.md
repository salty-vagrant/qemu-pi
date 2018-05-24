# qemu-raspbian-network
Launch Raspberry Pi image using QEMU and provision from scripts.

```
git clone https://github.com/salty-vagrant/qemu-pi.git
cd qemu-pi
wget https://downloads.raspberrypi.org/raspbian_lite_latest -O raspbian_lite_latest.zip
unzip raspbian_lite_latest.zip
sudo ./qemu-pi <image file unzipped above>
```

Note that it is recommended to use `qemu-arm` not older than 2.8.0 (a warning is issued if your QEMU is out of date)
