# this is integration of ns-3, outside traffic, FRER switch and different linux containers
SEMAFILE=/tmp/xdpfrer.envs
# export PS1="(xdpfrer)# "


alias nsx1="ip netns exec frerenv1" # switch at talker side
alias nsx2="ip netns exec frerenv2" # switch at listener side
alias tx="ip netns exec talker"
alias lx="ip netns exec listener"

ALIASES='alias tx="ip netns exec talker"; alias lx="ip netns exec listener"; alias nsx1="ip netns exec frerenv1";alias nsx2="ip netns exec frerenv2"'

if [ $(id -u) -ne 0 ]; then
  echo "Usage: run 'source env.sh' as root"
  return -1
fi

configure_netenv() {
  echo "Configure test network for XDP FRER..."

  ip netns add frerenv1
  ip netns add frerenv2
  ip netns add talker
  ip netns add listener

# R1 to R4 are containers that connect tap device to FRER switch
  # We need to relay on local tap devices created by ns-3 , use of tap device
  #outside ns3 and connecting them with bridge is having limitations
  ip netns add R1
  ip netns add R2
  ip netns add R3
  ip netns add R4


  NETNSES="R1 R2 R3 R4 frerenv1 frerenv2 talker listener"
  for item in $NETNSES; do
     ip netns exec $item sysctl -w net.ipv6.conf.all.disable_ipv6=1
     ip netns exec $item ip link set dev lo up
  done




 # Talker - Frerenv1 - R1-tap1/R2-tap2
 ip link add teth0 netns talker type veth peer name aeth0 netns frerenv1
 ip link add enp3s0 netns frerenv1 type veth peer name b_
 ip link set b_ netns R1
 ip netns exec R1 ip link set b_ up
 ip netns exec R1 ip addr add 192.168.63.10/24 dev b_

 ip link add enp6s0 netns frerenv1 type veth peer name d_
 ip link set d_ netns R2
 ip netns exec R2 ip link set d_ up 
 ip netns exec R2 ip addr add 192.168.63.11/24 dev d_



# #moving tap devices 

sudo ip link set tap1 netns R1
sudo ip netns exec R1 ip link set tap1 up
sudo ip netns exec R1 ip addr add 192.168.60.14/24 dev tap1

sudo ip link set tap2 netns R2
sudo ip netns exec R2 ip link set tap2 up
sudo ip netns exec R2 ip addr add 192.168.60.15/24 dev tap2




# listener - Frerenv2 - R3-tap3/R4-tap4
 ip link add leth0 netns listener type veth peer name beth0 netns frerenv2
 ip link add enp4s0 netns frerenv2 type veth peer name y_
 ip link set y_ netns R3
 ip netns exec R3 ip link set y_ up
 ip netns exec R3 ip addr add 192.168.62.11/24 dev y_



 ip link add enp7s0 netns frerenv2 type veth peer name v_
 ip link set v_ netns R4
 ip netns exec R4 ip link set v_ up
 ip netns exec R4 ip addr add 192.168.62.14/24 dev v_



 # # sudo ip tuntap add mode tap4 and  tap3
sudo ip link set tap3 netns R3
sudo ip netns exec R3 ip link set tap3 up
sudo ip netns exec R3 ip addr add 192.168.60.16/24 dev tap3

sudo ip link set tap4 netns R4
sudo ip netns exec R4 ip link set tap4 up
sudo ip netns exec R4 ip addr add 192.168.60.17/24 dev tap4


# link settings
sudo ip netns exec R1 ip link set dev b_ mtu 2000
sudo ip netns exec R1 ip link set dev b_ up
sudo ip netns exec R1 ethtool -K b_ gro on
sudo ip netns exec R1 ethtool -K b_ rxvlan off txvlan off
sudo ip netns exec R1 ethtool -K b_ rx off tx off

sudo ip netns exec R2 ip link set dev d_ mtu 2000
sudo ip netns exec R2 ip link set dev d_ up
sudo ip netns exec R2 ethtool -K d_ gro on
sudo ip netns exec R2 ethtool -K d_ rxvlan off txvlan off
sudo ip netns exec R2 ethtool -K d_ rx off tx off

sudo ip netns exec R3 ip link set dev y_ mtu 2000
sudo ip netns exec R3 ip link set dev y_ up
sudo ip netns exec R3 ethtool -K y_ gro on
sudo ip netns exec R3 ethtool -K y_ rxvlan off txvlan off
sudo ip netns exec R3 ethtool -K y_ rx off tx off


sudo ip netns exec R4 ip link set dev v_ mtu 2000
sudo ip netns exec R4 ip link set dev v_ up
sudo ip netns exec R4 ethtool -K v_ gro on
sudo ip netns exec R4 ethtool -K v_ rxvlan off txvlan off
sudo ip netns exec R4 ethtool -K v_ rx off tx off


  IFNAMES="aeth0 enp3s0 enp6s0"
  for item in $IFNAMES; do
    nsx1 ip link set dev $item mtu 2000
    nsx1 ip link set dev $item up
    nsx1 ethtool -K $item gro on
    # nsx sh -c "echo 1 > /sys/class/net/$item/threaded"
    nsx1 ethtool -K $item rxvlan off txvlan off
    nsx1 ethtool -K $item rx off tx off
  done
  
  IFNAMES="enp4s0 enp7s0 beth0"
  for item in $IFNAMES; do
    nsx2 ip link set dev $item mtu 2000
    nsx2 ip link set dev $item up
    nsx2 ethtool -K $item gro on
    # nsx sh -c "echo 1 > /sys/class/net/$item/threaded"
    nsx2 ethtool -K $item rxvlan off txvlan off
    nsx2 ethtool -K $item rx off tx off
  done
  

  # vxlan setting at tx/lx
  tx ip link set dev teth0 up
  tx ethtool -K teth0 gro on
  tx ethtool -K teth0 rxvlan off txvlan off tx off rx off
  lx ip link set dev leth0 up
  lx ethtool -K leth0 gro on
  lx ethtool -K leth0 rxvlan off txvlan off tx off rx off
  


  # Add VLAN interface to test encap
  tx ip link add link teth0 name teth0.10 type vlan id 10
  tx ip link set teth0.10 address 00:00:00:01:01:01
  tx ip nei add 192.168.62.12 dev teth0.10 lladdr 00:00:00:02:02:02
  tx ip link set dev teth0.10 up
  tx ip link set dev teth0 mtu 1800

  lx ip link add link leth0 name leth0.20 type vlan id 20
  lx ip link set leth0.20 address 00:00:00:02:02:02
  lx ip nei add 192.168.63.1 dev leth0.20 lladdr 00:00:00:01:01:01
  lx ip link set dev leth0.20 up
  lx ip link set dev leth0 mtu 1800
   
  #Assing IP addresses 
  tx ip addr add 192.168.63.1/24 dev  teth0.10
  lx ip addr add 192.168.62.12/24 dev leth0.20



# VXLAN, to make whole system work on layer 2

sudo ip netns exec R1 ip link add vxlan-R1 type vxlan id 100 local 192.168.60.14 remote 192.168.60.16 dev tap1 dstport 4789
sudo ip netns exec R1 ip addr add 192.168.63.12/24 dev vxlan-R1
sudo ip netns exec R1 ip link set vxlan-R1 up

sudo ip netns exec R1 brctl addbr br0
sudo ip netns exec R1 brctl addif br0 b_
sudo ip netns exec R1 brctl addif br0 vxlan-R1
sudo ip netns exec R1 ip link set br0 up

sudo ip netns exec R3 ip link add vxlan-R3 type vxlan id 100 local 192.168.60.16 remote 192.168.60.14 dev tap3 dstport 4789
sudo ip netns exec R3 ip addr add 192.168.63.14/24 dev vxlan-R3
sudo ip netns exec R3 ip link set vxlan-R3 up


sudo ip netns exec R3 brctl addbr br0
sudo ip netns exec R3 brctl addif br0 y_
sudo ip netns exec R3 brctl addif br0 vxlan-R3
sudo ip netns exec R3 ip link set br0 up

sudo ip netns exec R2 ip link add vxlan-R2 type vxlan id 101 local 192.168.60.15 remote 192.168.60.17 dev tap2 dstport 4789
sudo ip netns exec R2 ip addr add 192.168.63.13/24 dev vxlan-R2
sudo ip netns exec R2 ip link set vxlan-R2 up




sudo ip netns exec R2 brctl addbr br0
sudo ip netns exec R2 brctl addif br0 d_
sudo ip netns exec R2 brctl addif br0 vxlan-R2
sudo ip netns exec R2 ip link set br0 up


sudo ip netns exec R4 ip link add vxlan-R4 type vxlan id 101 local 192.168.60.17 remote 192.168.60.15 dev tap4 dstport 4789
sudo ip netns exec R4 ip addr add 192.168.63.15/24 dev vxlan-R4
sudo ip netns exec R4 ip link set vxlan-R4 up


sudo ip netns exec R4 brctl addbr br0
sudo ip netns exec R4 brctl addif br0 v_
sudo ip netns exec R4 brctl addif br0 vxlan-R4
sudo ip netns exec R4 ip link set br0 up


sudo ip netns exec R1 bridge fdb append 00:00:00:00:00:00 dev vxlan-R1 dst 192.168.60.16
sudo ip netns exec R3 bridge fdb append 00:00:00:00:00:00 dev vxlan-R3 dst 192.168.60.14
sudo ip netns exec R2 bridge fdb append 00:00:00:00:00:00 dev vxlan-R2 dst 192.168.60.17



#routing


sudo ip netns exec talker ip route add default via 192.168.63.1 dev  teth0.10
sudo ip netns exec listener ip route add default via 192.168.62.12 dev leth0.20

sudo ip netns exec R1 ip route add 192.168.63.1 dev b_ src 192.168.63.10

sudo ip netns exec R3 ip route add 192.168.62.12 dev y_ src 192.168.62.11


sudo ip netns exec R2 ip route add 192.168.63.1 dev d_ src 192.168.63.11

sudo ip netns exec R4 ip route add 192.168.62.12 dev v_ src 192.168.62.14


sudo ip netns exec R1 sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec R3 sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec R2 sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec R4 sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec frerenv1 sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec frerenv2 sysctl -w net.ipv4.ip_forward=1
ip netns exec frerenv1 sysctl -w net.ipv4.conf.all.proxy_arp=1
ip netns exec frerenv1 sysctl -w net.ipv4.conf.default.proxy_arp=1
ip netns exec frerenv2 sysctl -w net.ipv4.conf.all.proxy_arp=1
ip netns exec frerenv2 sysctl -w net.ipv4.conf.default.proxy_arp=1


ip netns exec talker ip route add 224.0.0.0/8 dev teth0.10
ip netns exec listener ip route add 224.0.0.0/8 dev leth0.20

# sudo ip netns exec frerenv1 ip link set enp3s0 down
#sudo ip netns exec talker arp -s 192.168.63.2 1e:4a:7e:2e:b8:85

  # mkdir -p /tmp/xdpfrerbpffs
  # export LIBXDP_BPFFS=/tmp/xdpfrerbpffs/
  # export LIBXDP_BPFFS_AUTOMOUNT=1
  # mount --bind /sys/fs/bpf/ /tmp/xdpfrerbpffs
nsx1 ../src/xdpfrer -m repl -i aeth0:10 -e enp3s0:55 -e enp6s0:56 & nsx2 ../src/xdpfrer -m elim -i enp4s0:55 -i enp7s0:56 -e beth0:20 & nsx2 ../src/xdpfrer -m repl -i beth0:20 -e enp4s0:66 -e enp7s0:67 & nsx1 ../src/xdpfrer -m elim -i enp3s0:66 -i enp6s0:67 -e aeth0:10


 }


cleanup() {
  echo "Cleanup XDP FRER test network..."
  # umount /tmp/xdpfrerbpffs
  # rmdir /tmp/xdpfrerbpffs
  ip netns del talker
  ip netns del listener
  
  ip netns del frerenv1
  ip netns del frerenv2
  ip netns del R1
  ip netns del R2
  ip netns del R3
  ip netns del R4
  
  unset LIBXDP_BPFFS
  unset LIBXDP_BPFFS_AUTOMOUNT

    # Remove tap interfaces if they exist
    for i in tap1 tap2 tap3 tap4; do
        #if ip link show "$i" &> /dev/null; then
            sudo ip link set "$i" down
            sudo ip tuntap del dev "$i" mode tap
        #fi
    done
}

if [ -f "$SEMAFILE" ]; then
  cntvalue=`cat $SEMAFILE`
  newvalue=`expr $cntvalue + 1`
  echo $newvalue > $SEMAFILE
else
  configure_netenv
  echo "1" > $SEMAFILE
fi

/bin/bash --init-file <(echo "$ALIASES; PS1='(veth.env) \u:\W# '")

cntvalue=`cat $SEMAFILE`
if [ $cntvalue -eq 1 ]; then #last bash instance in the env, do cleanup
  rm $SEMAFILE
  cleanup
else
  newvalue=`expr $cntvalue - 1`
  echo $newvalue > $SEMAFILE
fi