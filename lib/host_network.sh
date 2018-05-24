#!/bin/bash

restore_qemu_up_down_scripts() {
  echo "  Restoring QEMU up/down scripts"
  test -f /etc/qemu-ifup.bak   && cp -nav /etc/qemu-ifup.bak   /etc/qemu-ifup
  test -f /etc/qemu-ifdown.bak && cp -nav /etc/qemu-ifdown.bak /etc/qemu-ifdown
}

qemu_up_down_scripts() {
  echo "  Configuring QEMU up/down scripts"
  test -f /etc/qemu-ifup   && cp -nav /etc/qemu-ifup   /etc/qemu-ifup.bak
  test -f /etc/qemu-ifdown && cp -nav /etc/qemu-ifdown /etc/qemu-ifdown.bak

  prefix_trap "restore_qemu_up_down_scripts" EXIT

  cat > /etc/qemu-ifup <<EOF
#!/bin/sh
echo "Executing /etc/qemu-ifup"
echo "Bringing up \$1 for bridged mode..."
sudo $BINARY_PATH/ip link set \$1 up promisc on
echo "Adding \$1 to $BRIDGE..."
sudo $BINARY_PATH/brctl addif $BRIDGE \$1
sleep 2
EOF

  cat > /etc/qemu-ifdown <<EOF
#!/bin/sh
echo "Executing /etc/qemu-ifdown"
sudo $BINARY_PATH/ip link set \$1 down
sudo $BINARY_PATH/brctl delif $BRIDGE \$1
sudo $BINARY_PATH/ip link delete dev \$1
EOF

  chmod 750 /etc/qemu-ifdown /etc/qemu-ifup
  chown root:kvm /etc/qemu-ifup /etc/qemu-ifdown

}

restore_ip_forwarding() {
  echo "  Restoring ip forwarding"
  sysctl net.ipv4.ip_forward=${IPFW} >/dev/null
}

set_ip_forwarding() {
  IPFW=$( sysctl net.ipv4.ip_forward | cut -d= -f2 | xargs)
  echo "  Setting ip forwarding"
  prefix_trap "restore_ip_forwarding" EXIT
  sysctl net.ipv4.ip_forward=1 >/dev/null
}


remove_bridge_device() {
  echo "  Removing bridge device $BRIDGE"
  brctl delbr $BRIDGE
}

tear_down_bridge() {
  echo "  Tearing down bridge dev $BRIDGE"
  echo "    Removing $IFACE interface from bridge $BRIDGE"
  brctl delif $BRIDGE $IFACE
  ip link set down dev $BRIDGE
  # This is a bit brutal. Should really use DHCP if that's how the IF is configured and the IP is lost
  echo "    Restore IP (${IP}) to ${IFACE}"
  ip address add $IP dev $IFACE
}

setup_bridge_dev() {
  echo "  Creating new bridge: $BRIDGE..."
  brctl addbr $BRIDGE
  prefix_trap "remove_bridge_device" EXIT
  echo "    Adding $IFACE interface to bridge $BRIDGE"
  brctl addif $BRIDGE $IFACE
  echo "    Setting link up for: $BRIDGE"
  ip link set up dev $BRIDGE
  prefix_trap "tear_down_bridge" EXIT
  echo "    Adding IP address to bridge: $BRIDGE"
  ip address add $IP dev $BRIDGE
}

restore_routes() {
  echo "  Restoring routes..."
  echo "    Flush routes on bridge dev $BRIDGE"
  ip route flush dev $BRIDGE
  echo "    Flush routes on dev $IFACE"
  ip route flush dev $IFACE
  echo "    Rewriting $IFACE routes"
  echo "$ROUTES" | tac | while read l; do ip route add $l; done
}

setup_routes() {
  echo "  Setting up new routes..."
  echo "    Getting routes for interface: $IFACE"
  ROUTES=$( ip route | grep $IFACE )
  echo "    Changing those routes to bridge interface: $BRIDGE"
  BRROUT=$( echo "$ROUTES" | sed "s=$IFACE=$BRIDGE=" )
  echo "    Flushing routes to interface: $IFACE"
  prefix_trap "restore_routes" EXIT
  ip route flush dev $IFACE
  echo "    Adding routes to bridge: $BRIDGE"
  echo "$BRROUT" | tac | while read l; do ip route add $l; done
  echo "    Routes to bridge $BRIDGE added"
}


teardown_tap_dev() {
  # Under normal circumstances this is done by the qemuif-down script
  # this is just a precaution against abnormal shutdown
  echo "  Tearing down tap dev $TAPIF"
  ip link set down dev $TAPIF 2>/dev/null
  ip tuntap del $TAPIF mode tap 2>/dev/null
}

setup_tap_dev() {
  echo "  Setting up tap device"
  precreationg=$(ip tuntap list | cut -d: -f1 | sort)
  ip tuntap add user $USER mode tap
  postcreation=$(ip tuntap list | cut -d: -f1 | sort)
  TAPIF=$(comm -13 <(echo "$precreationg") <(echo "$postcreation"))
  prefix_trap "teardown_tap_dev" EXIT
}


setup_host_network() {
  echo "Setting up host network"
  qemu_up_down_scripts
  set_ip_forwarding
  setup_bridge_dev
  setup_routes
  setup_tap_dev
  prefix_trap 'echo "Restoring host network..."' EXIT
}

