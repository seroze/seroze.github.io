---
layout: post
title: "Design streaming server middleware for frontends"
date: 2025-03-01 10:00:00 +0530
categories: introduction personal
tags: [distributed-systems]
author: "Seroze"
---

Every application has a state which can change over time now we want to consume this stream from different apps, we want to develop a middleware service that can consume this stream and provide a filtered view via websocket to various clients like web browser or apps.

Eg: Imagine we want to build a frontend app that shows your portfolio (sum of current stock price * no_of_stocks_we_are_currently_holding) this is a dynamic information.
On the surface this looks simple right just subscribe to a kafka topic and do computation over it ?

![Middleware for Frontend](/assets/images/middleware-for-frontend.jpeg)

Web browsers are constrained by a single thread so instead of subscribing and filtering the data at browser let’s do the filtering at the server end (i.e move the computation part to the backend server).

Functional advantages:

- Gateways (kafka source or rabbitMQ source or whatever)
- filtering, aggregation, sort-and-limit
- rate-limiting
- authorization and authentication
- dynamic subscription management and session details
  - when you open 10 tabs we need to only stream data to the current one we can stop sending data to other tabs

Non functional advantages:
- load balancing
- disaster recovery
- sharding

Some web optimisations
use batching (Eg: send 100 records instead of 1 by 1)
to avoid network congestion throttle (i.e conflate the records and send the info)
use delta updates (i.e only send what changed instead of sending whole information.

For example if in a portfolio only the market price changed then just send that only)
serialization format can be json, protobuf would be faster but for the schema has to be maintained and transferrring delta updates is not possible.
