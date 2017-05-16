title:  Tuning The Linux Connection Tracking System
date: 2017-05-16
tags:
- kubernetes
- iptables
- conntrack
---

我们将大量的api部署在k8s上，有一次一个app后端的服务器进行了重启引起几十万的连接到api上重新验证，导致k8s的ConntrackTable满的告警，分析发现node-exporter(Prometheus node-exporter)监控的node_nf_conntrack_entries / node_nf_conntrack_entries_limit满。既然告警了就应该了解下这个告警是什么意思。

下面是google到的内容，看看Conntract table做什么的：

# The Connection Tracking/Conntrack Modules

It is a tracking technique of the connections. It is used to know how the packets that pass through the system are related to their connections. The connection tracking does NOT manipulate the packets and It works independently of the NAT module. The conntrack entry looks like:

udp 17 170 src=192.168.1.2 dst=192.168.1.5 sport=137 dport=1025 src=192.168.1.5 dst=192.168.1.2 sport=1025 dport=137 [ASSURED] use=1

The conntrack entry is stored into two separate tuples (one for the original direction (red) and another for the reply direction (blue)). Tuples could belong to different linked lists/buckets in conntrack hash table. The connection tracking modules is responsible for creating and removing the tuples.

Note: The tracking of the connections is ALSO used by iptables to do packet matching based on the connection state.

# 验证

要查询Conntract table的内容可以通过/proc

```
# cat /proc/net/nf_conntrack | head -5
ipv4     2 tcp      6 86385 ESTABLISHED src=192.168.10.1 dst=192.168.10.1 sport=41230 dport=2379 src=192.168.10.1 dst=192.168.10.1 sport=2379 dport=41230 [ASSURED] mark=0 zone=0 use=2
ipv4     2 tcp      6 86389 ESTABLISHED src=127.0.0.1 dst=127.0.0.1 sport=33294 dport=8080 src=127.0.0.1 dst=127.0.0.1 sport=8080 dport=33294 [ASSURED] mark=0 zone=0 use=2
ipv4     2 tcp      6 86398 ESTABLISHED src=192.168.10.1 dst=192.168.10.1 sport=55688 dport=2379 src=192.168.10.1 dst=192.168.10.1 sport=2379 dport=55688 [ASSURED] mark=0 zone=0 use=2
ipv4     2 tcp      6 86393 ESTABLISHED src=192.168.10.1 dst=192.168.10.1 sport=57118 dport=2379 src=192.168.10.1 dst=192.168.10.1 sport=2379 dport=57118 [ASSURED] mark=0 zone=0 use=2
ipv4     2 tcp      6 86386 ESTABLISHED src=127.0.0.1 dst=127.0.0.1 sport=39722 dport=8080 src=127.0.0.1 dst=127.0.0.1 sport=8080 dport=39722 [ASSURED] mark=0 zone=0 use=2
```

从上面的内容看出nf_conntrack记录的是ip和port的映射情况


统计nf_conntrack_entries可以通过wc

```
cat /proc/net/nf_conntrack | wc -l
```

因为k8s的proxy目前采用的是iptables，所以必然需要存放大量的nf_conntrack链接信息，如果k8s节点的通讯量太大就可能导致nf_conntrack表的信息满，所以这个参数应该是k8s中相对比较重要的一个监控指标


查看nf_conntrack table的限制

```
# sysctl -a|grep -i nf_conntrack_max
net.netfilter.nf_conntrack_max = 262144
net.nf_conntrack_max = 262144
```

conntrack bucket

```
# sysctl -a|grep -i nf_conntrack_buckets
net.netfilter.nf_conntrack_buckets = 65536
```

bucket size = 4 (262144/65536)



修改max

```
echo "net.netfilter.nf_conntrack_max = 131072" >> /etc/sysctl.conf
sysct -p
```

其他配置参数：

```
# sysctl -a|grep -i nf_conntrack
net.netfilter.nf_conntrack_acct = 0
net.netfilter.nf_conntrack_buckets = 65536
net.netfilter.nf_conntrack_checksum = 1
net.netfilter.nf_conntrack_count = 431
net.netfilter.nf_conntrack_events = 1
net.netfilter.nf_conntrack_events_retry_timeout = 15
net.netfilter.nf_conntrack_expect_max = 1024
net.netfilter.nf_conntrack_frag6_high_thresh = 4194304
net.netfilter.nf_conntrack_frag6_low_thresh = 3145728
net.netfilter.nf_conntrack_frag6_timeout = 60
net.netfilter.nf_conntrack_generic_timeout = 600
net.netfilter.nf_conntrack_helper = 1
net.netfilter.nf_conntrack_icmp_timeout = 30
net.netfilter.nf_conntrack_icmpv6_timeout = 30
net.netfilter.nf_conntrack_log_invalid = 0
net.netfilter.nf_conntrack_max = 262144
net.netfilter.nf_conntrack_tcp_be_liberal = 0
net.netfilter.nf_conntrack_tcp_loose = 1
net.netfilter.nf_conntrack_tcp_max_retrans = 3
net.netfilter.nf_conntrack_tcp_timeout_close = 10
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 3600
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_last_ack = 30
net.netfilter.nf_conntrack_tcp_timeout_max_retrans = 300
net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 60
net.netfilter.nf_conntrack_tcp_timeout_syn_sent = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_unacknowledged = 300
net.netfilter.nf_conntrack_timestamp = 0
net.netfilter.nf_conntrack_udp_timeout = 30
net.netfilter.nf_conntrack_udp_timeout_stream = 180
net.nf_conntrack_max = 262144
```


ref:
[https://voipmagazine.wordpress.com/tag/nf_conntrack/](https://voipmagazine.wordpress.com/tag/nf_conntrack/)
[https://voipmagazine.wordpress.com/tag/conntrack-entry/](https://voipmagazine.wordpress.com/tag/conntrack-entry/)
