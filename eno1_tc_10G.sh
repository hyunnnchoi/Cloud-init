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

# Filter options for limiting the intended interface.
U32="$TC filter add dev $IF protocol ip parent 1:0 prio 1 u32"

start() {
    # We'll use Hierarchical Token Bucket (HTB) to shape bandwidth.
    # For detailed configuration options, please consult Linux man page.
    $TC qdisc del dev $IF root 2>/dev/null  # 기존 규칙 제거
    
    $TC qdisc add dev $IF root handle 1: htb default 10
    $TC class add dev $IF parent 1: classid 1:1 htb rate $DNLD
    $TC class add dev $IF parent 1: classid 1:2 htb rate $UPLD
    
    # 자동으로 찾은 IP 주소에 대한 필터 추가
    $U32 match ip dst $IP/32 flowid 1:1
    $U32 match ip src $IP/32 flowid 1:2

    echo "Bandwidth shaping active on $IF ($IP) with upload: $UPLD, download: $DNLD"
}

stop() {
    # Stop the bandwidth shaping.
    $TC qdisc del dev $IF root 2>/dev/null
    echo "Bandwidth shaping stopped on $IF"
}

restart() {
    # Self-explanatory.
    stop
    sleep 1
    start
}

show() {
    # Display status of traffic control status.
    echo "Qdisc configuration:"
    $TC -s qdisc ls dev $IF
    echo ""
    echo "Class configuration:"
    $TC -s class ls dev $IF
    echo ""
    echo "Filter configuration:"
    $TC -s filter ls dev $IF
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
