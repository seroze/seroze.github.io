---
layout: post
title: "Apache ZooKeeper usecases"
date: 2025-03-01 10:00:00 +0530
categories: introduction personal
tags: [distributed-systems, zookeeper]
author: "Seroze"
---

You hear about apache zookeeper frequently while reading about kafka etc.. today i’ll share some basic details about it. Refer https://zookeeper.apache.org/doc/current/zookeeperTutorial.html for the official specification.

ZooKeeper can be used as
- configuration management
- service discovery
- synchronisation
- leader election

ZooKeeper maintains a cluster of leader and replica instances running and read requests can be served by any node, but write requests have to be routed through the leader instance.

![writes are redirected to leader, diagram source: https://www.youtube.com/watch?v=iHrsHqSAe18](/assets/images/zk-1.png)
---------------------------------------------
![reads can be served by any replica/leader, source: https://www.youtube.com/watch?v=iHrsHqSAe18](/assets/images/zk-2.png)


ZooKeeper terminologies

Znode
- it’s like a file system node
- you can store some blob data on each node typically it is less than 1M, it cannot be large (use other things like HDFS/NFS if you want to store large data)
- you can have ephemeral zNodes which can’t have children

I’ll add more examples on where zooKeeper is used for the above usecases
