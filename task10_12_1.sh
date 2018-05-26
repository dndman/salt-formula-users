#!/bin/bash


set -x
set -e
#adding a kvm
modprobe kvm
DIRWAY=$(dirname $(readlink -f ${BASH_SOURCE[0]}) )
#update and install libvirt and a tool for making .iso for cloud-config
apt update
apt  install -y qemu libvirt-bin genisoimage virtinst
$DIRWAY/netkiller || true
ssh-keygen -t rsa -N "" -f /tmp/id_rsa

#adding a conf file as a data source
. $DIRWAY/config
#making directory for xml templates
mkdir -p $DIRWAY/networks

#generating MAC for external if on VM1
if [ ! -f /tmp/mac ] ; then
MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
echo "MAC=$MAC" > /tmp/mac
else
. /tmp/mac
fi


#making templates for lib networks
echo "
<network>
    <name>$INTERNAL_NET_NAME</name>
    <bridge name='internalbr' />
</network>
" > $DIRWAY/networks/${INTERNAL_NET_NAME}.xml

echo "
<network>
    <name>$MANAGEMENT_NET_NAME</name>
    <bridge name='managementbr' />
    <forward mode='route'/>
    <ip address='$MANAGEMENT_HOST_IP' netmask='$MANAGEMENT_NET_MASK' />
</network>
" > $DIRWAY/networks/${MANAGEMENT_NET_NAME}.xml

echo "
<network>
    <name>$EXTERNAL_NET_NAME</name>
    <bridge name='externalbr' />
    <forward mode='nat' />
    <ip address='$EXTERNAL_NET_HOST_IP' netmask='$EXTERNAL_NET_MASK'>
        <dhcp>
            <range start='$VM1_EXTERNAL_IP' end='$VM1_EXTERNAL_IP' />
         <host mac='$MAC' name='$VM1_NAME' ip='$VM1_EXTERNAL_IP'/>

</dhcp>
    </ip>
</network>
" > $DIRWAY/networks/${EXTERNAL_NET_NAME}.xml

#creating networks from templates
virsh net-define $DIRWAY/networks/${INTERNAL_NET_NAME}.xml
virsh net-define $DIRWAY/networks/${MANAGEMENT_NET_NAME}.xml
virsh net-define $DIRWAY/networks/${EXTERNAL_NET_NAME}.xml

virsh net-start $INTERNAL_NET_NAME
virsh net-start $EXTERNAL_NET_NAME
virsh net-start $MANAGEMENT_NET_NAME

virsh net-autostart $INTERNAL_NET_NAME
virsh net-autostart $EXTERNAL_NET_NAME
virsh net-autostart $MANAGEMENT_NET_NAME



#making directory for config files of VMs
mkdir -p $DIRWAY/config-drives/vm1-config $DIRWAY/config-drives/vm2-config

#create meta-data dir and files for VMs
echo "instance-id: iid-${VM1_NAME}
local-hostname: $VM1_NAME
" > $DIRWAY/config-drives/vm1-config/meta-data

echo "instance-id: iid-${VM2_NAME}
local-hostname: $VM2_NAME
" > $DIRWAY/config-drives/vm2-config/meta-data

#making cloud-config for VMs
echo "#cloud-config
#ssh_svcname: ssh
runcmd:
#  - ip link set $VM1_MANAGEMENT_IF down && ip link set $VM1_MANAGEMENT_IF up
#  - ip addr add $VM1_MANAGEMENT_IP/$MANAGEMENT_NET_MASK dev $VM1_MANAGEMENT_IF
#  - ip link set $VM1_EXTERNAL_IF down && ip link set $VM1_EXTERNAL_IF up
  - ifup $VM1_EXTERNAL_IF
  - ifup $VM1_INTERNAL_IF
  - ifup $VM1_MANAGEMENT_IF
  - ifup $VXLAN_IF
  - sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  - sysctl -p
  - iptables -t nat -A POSTROUTING -o $VM1_EXTERNAL_IF -s $VM1_INTERNAL_IP/$INTERNAL_NET_MASK -j MASQUERADE
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\"
  - apt-get update
  - apt-get -y install docker-ce

  - touch /tmp/complete

ssh_authorized_keys:
  - $(cat $SSH_PUB_KEY)
  - $(cat /tmp/id_rsa.pub)
chpasswd:
  list: |
    root:root
  expire: False

disable_root: false

#network:
# config: disabled

write_files:
   - path: /etc/network/interfaces
     content: |
          auto $VM1_EXTERNAL_IF
           iface $VM1_EXTERNAL_IF inet dhcp

          auto $VM1_INTERNAL_IF
           iface $VM1_INTERNAL_IF inet static
           address $VM1_INTERNAL_IP
           netmask $INTERNAL_NET_MASK
           dns-nameservers $VM_DNS

          auto $VM1_MANAGEMENT_IF
           iface $VM1_MANAGEMENT_IF inet static
           address $VM1_MANAGEMENT_IP
           netmask $MANAGEMENT_NET_MASK
          # gateway $MANAGEMENT_HOST_IP

          auto $VXLAN_IF
           iface $VXLAN_IF inet static
            pre-up ip link add $VXLAN_IF type vxlan id $VID group 239.0.0.10 dev $VM1_INTERNAL_IF || true
            up ip link set $VXLAN_IF up
            down ip link set $VXLAN_IF down
            post-down ip link del $VXLAN_IF || true
            address $VM1_VXLAN_IP
            netmask $INTERNAL_NET_MASK

   - path: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
     content: |
          network: {config: disabled}


" > $DIRWAY/config-drives/vm1-config/user-data



echo "#cloud-config
#ssh_svcname: ssh
runcmd:
#  - ip link set $VM2_MANAGEMENT_IF down && ip link set $VM2_MANAGEMENT_IF up
#  - ip addr add $VM2_MANAGEMENT_IP/$MANAGEMENT_NET_MASK dev $VM2_MANAGEMENT_IF
  - rm -f /etc/network/interfaces.d/*
  - ifdown $VM2_INTERNAL_IF
  - ifup $VM2_INTERNAL_IF
  - ifup $VM2_MANAGEMENT_IF
  - ifup $VXLAN_IF
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\"
  - apt-get update
  - apt-get -y install docker-ce
  - touch /tmp/complete

ssh_authorized_keys:
  - $(cat $SSH_PUB_KEY)
  - $(cat /tmp/id_rsa.pub)

chpasswd:
  list: |
    root:root
  expire: False

disable_root: false

#network:
#  config: disabled

write_files:
   - path: /etc/network/interfaces
     content: |
          auto $VM2_INTERNAL_IF
           iface $VM2_INTERNAL_IF inet static
           address $VM2_INTERNAL_IP
           netmask $INTERNAL_NET_MASK
           dns-nameservers $VM_DNS
           up ip route add default via $VM1_INTERNAL_IP dev $VM2_INTERNAL_IF

          auto $VM2_MANAGEMENT_IF
           iface $VM2_MANAGEMENT_IF inet static
           address $VM2_MANAGEMENT_IP
           netmask $MANAGEMENT_NET_MASK
           #gateway $MANAGEMENT_HOST_IP


          auto $VXLAN_IF
           iface $VXLAN_IF inet static
            pre-up ip link add $VXLAN_IF type vxlan id $VID group 239.0.0.10 dev $VM2_INTERNAL_IF || true
            up ip link set $VXLAN_IF up
            down ip link set $VXLAN_IF down
            post-down ip link del $VXLAN_IF || true
            address $VM2_VXLAN_IP
            netmask $INTERNAL_NET_MASK

   - path: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
     content: |
          network: {config: disabled}


" > $DIRWAY/config-drives/vm2-config/user-data

#making a directories to store "hdd" of VMs
mkdir -p $(dirname "${VM1_HDD}")
mkdir -p $(dirname "${VM2_HDD}")

#making iso files for cloud-config
mkisofs -R -V cidata -joliet -o $VM1_CONFIG_ISO $DIRWAY/config-drives/vm1-config
mkisofs -R -V cidata -joliet -o $VM2_CONFIG_ISO $DIRWAY/config-drives/vm2-config


#download image and making a "hdd" for VM1 from it
if [ ! -f /tmp/ubuntu.qcow2 ] ; then
wget $VM1_BASE_IMAGE -O /tmp/ubuntu.qcow2
wget $VM1_BASE_IMAGE -O /tmp/centos.qcow2
qemu-img resize /tmp/ubuntu.qcow2 +100GB
qemu-img resize /tmp/centos.qcow2 +100GM
fi
#copying "hdd" of VM1 to create VM2
cp /tmp/ubuntu.qcow2 $VM1_HDD
cp /tmp/centos.qcow2 $VM2_HDD

#installing a VM1
sudo virt-install \
--import \
--name $VM1_NAME \
--ram $VM1_MB_RAM \
--vcpus $VM1_NUM_CPU \
--disk ${VM1_HDD},format=qcow2,bus=virtio \
--disk ${VM1_CONFIG_ISO},device=cdrom \
--network bridge=externalbr,model=virtio,mac=$MAC \
--network bridge=internalbr,model=virtio \
--network bridge=managementbr,model=virtio \
--graphics none \
--noautoconsole

$DIRWAY/cycle $VM1_MANAGEMENT_IP

#installing a VM2
sudo virt-install \
--import \
--name $VM2_NAME \
--ram $VM2_MB_RAM \
--vcpus $VM2_NUM_CPU \
--disk ${VM2_HDD},format=qcow2,bus=virtio \
--disk ${VM2_CONFIG_ISO},device=cdrom \
--network bridge=internalbr,model=virtio \
--network bridge=managementbr,model=virtio \
--graphics none \
--noautoconsole

$DIRWAY/cycle $VM2_MANAGEMENT_IP

