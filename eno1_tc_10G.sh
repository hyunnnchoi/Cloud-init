#!/bin/bash
#
#  tc uses the following units when passed as a parameter.
#  kbps: Kilobytes per second
#  mbps: Megabytes per second
#  kbit: Kilobits per second
#  mbit: Megabits per second
#  bps: Bytes per second
#       Amounts of data can be specified in:
#       kb or k: Kilobytes
#       mb or m: Megabytes
#       mbit: Megabits
#       kbit: Kilobits
#  To get the byte figure from bits, divide the number by 8 bit
#
#
# Name of the traffic control command.
TC=/sbin/tc
# The network interface we're planning on limiting bandwidth.
IF=eno1            # Interface
# Download limit (in mega bits)
DNLD=10000mbit     # DOWNLOAD Limit
# Upload limit (in mega bits)
UPLD=10000mbit     # UPLOAD Limit

# 자동으로 eno1 인터페이스의 IP 주소 가져오기
IP=$(ip -4 addr show dev $IF | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
# 자동으로 IP를 가져오지 못한 경우 에러 메시지 출력
if [ -z "$IP" ]; then
    echo "Error: Could not get IP address for interface $IF"
    exit 1
fi
echo "Using interface $IF with IP address $IP"

start() {
    # 기존 qdisc 제거(있다면)
    $TC qdisc del dev $IF root 2>/dev/null
    $TC qdisc del dev $IF ingress 2>/dev/null

    # 송신(egress) 트래픽 제어 설정
    echo "Setting up egress (outgoing) traffic control..."
    $TC qdisc add dev $IF root handle 1: htb default 10
    $TC class add dev $IF parent 1: classid 1:10 htb rate $UPLD ceil $UPLD burst 15k
    
    # 더 강력한 큐 설정 - Fair Queuing with Controlled Delay
    $TC qdisc add dev $IF parent 1:10 fq_codel
    
    # 수신(ingress) 트래픽 제어를 위한 ifb 설정
    echo "Setting up ingress (incoming) traffic control..."
    modprobe ifb
    
    # ifb 디바이스 설정
    IFB="ifb0"
    $TC qdisc del dev $IFB root 2>/dev/null
    ip link set dev $IFB down 2>/dev/null
    ip link del $IFB 2>/dev/null
    
    ip link add $IFB type ifb
    ip link set dev $IFB up
    
    # 수신 트래픽을 ifb로 리다이렉션
    $TC qdisc add dev $IF handle ffff: ingress
    $TC filter add dev $IF parent ffff: protocol all u32 match u32 0 0 action mirred egress redirect dev $IFB
    
    # ifb 디바이스에 대역폭 제한 설정
    $TC qdisc add dev $IFB root handle 1: htb default 10
    $TC class add dev $IFB parent 1: classid 1:10 htb rate $DNLD ceil $DNLD burst 15k
    $TC qdisc add dev $IFB parent 1:10 fq_codel
    
    echo "Bandwidth shaping is now active"
}

stop() {
    # Stop the bandwidth shaping.
    echo "Removing traffic control settings..."
    $TC qdisc del dev $IF root 2>/dev/null
    $TC qdisc del dev $IF ingress 2>/dev/null
    
    # ifb 디바이스 제거
    IFB="ifb0"
    $TC qdisc del dev $IFB root 2>/dev/null
    ip link set dev $IFB down 2>/dev/null
    # ip link del $IFB 2>/dev/null  # 주석 처리: 다른 프로세스가 사용 중일 수 있음
    
    echo "Traffic control settings removed"
}

restart() {
    # Self-explanatory.
    stop
    sleep 1
    start
}

show() {
    # Display status of traffic control status with more details.
    echo "Egress QDisc information (outgoing):"
    $TC -s qdisc ls dev $IF
    echo ""
    echo "Egress Class information (outgoing):"
    $TC -s class ls dev $IF
    echo ""
    echo "Egress Filter information (outgoing):"
    $TC -s filter ls dev $IF
    
    echo ""
    echo "Ingress QDisc information (incoming):"
    $TC -s qdisc ls dev ifb0 2>/dev/null
    echo ""
    echo "Ingress Class information (incoming):"
    $TC -s class ls dev ifb0 2>/dev/null
    echo ""
    echo "Ingress Filter information (incoming):"
    $TC -s filter ls dev ifb0 2>/dev/null
}

case "$1" in
  start)
    echo -n "Starting bandwidth shaping: "
    start
    echo "done"
    ;;
  stop)
    echo -n "Stopping bandwidth shaping: "
    stop
    echo "done"
    ;;
  restart)
    echo -n "Restarting bandwidth shaping: "
    restart
    echo "done"
    ;;
  show)
    echo "Bandwidth shaping status for $IF ($IP):"
    show
    echo ""
    ;;
  *)
    pwd=$(pwd)
    echo "Usage: $0 {start|stop|restart|show}"
    ;;
esac
