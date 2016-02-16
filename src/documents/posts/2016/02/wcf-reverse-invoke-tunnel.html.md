---
title: "WCF Reverse invoke tunnel"
layout: "post"
date: 2016-02-12
summary: "In typical multi-layered system client layer connects to service layer and retrieves information. But what if we need to reverse that flow?"
summaryImage: "/images/posts/wcf-reverse-invoke-small.png"
tags: [WCF, Reverse invoke, WCF behavior, WCF duplex]
---

In typical multi-layered system client layer connects to service layer and retrieves information. But what if we need to reverse that flow?

Recently we had a request from client's security department to change architecture so that our web application deployed in DMZ zone never directly invokes our middleware application deployed in intranet zone. Between these zones administrators will install firewall that will block all incoming calls from DMZ to intranet.

In this article I will describe the solution I designed for this specific problem. Although I cannot post source code, since this is company project, I will do my best to explain general idea behind solution so anyone with similar problem can follow guidelines to implement working solution.

Since we are using WCF for all our services first we tried to find existing solution to the problem and to find out if maybe it's WCF feature supported out of the box. To our surprise there was no existing .NET solution for this problem nor WCF feature we could use. So we decided to roll our own.

We agreed that solution should meet these requirements:

1. Solution must be transparent to the current architecture. In other words apps from DMZ and intranet zones must not change. Ideally only configuration should change. Developers continue to use WCF technology for communication between different layers in the same way as if there was no reverse connection requirement. Administrators will configure reverse connection during deployment.
2. Solution must support WCF security features over reverse connection.
3. Solution must have similar performance as direct communication in terms of speed and scalability.
4. Solution must be highly available.

## Proposed architecture ##

After considering options I proposed architecture with custom application tunnel between DMZ and intranet zones. This architecture includes two intermediary routers, in further text R1 and R2, that form application tunnel. Messages sent to the R1 router will be forwarded to R2 router using reverse connection. After that R2 router must route message to the destination service.

<img class="centered img-responsive" src="/images/posts/wcf-reverse-invoke.png" title="Proposed architecture" />

The following steps describe general flow of communication:

1. Router R1 starts.
2. Router R2 starts and tries to connect to R1 in regular intervals. First established connection is called management connection.
3. R1 can use management connection to ask R2 to create more connections (if needed for high load).
4. Additional connections from R2 are stored in custom connection pool.
5. When incoming request arrives web application forwards it to R1 router. R1 uses connection from pool to send request to R2. R2 routes request to the destination.

Basic idea behind reverse connection is to reuse connection already opened by service instead of establishing new one. Of course, this is possible only by using statefull protocol like TCP. If we want to translate that idea to WCF we can use WCF duplex binding or more specific - duplex channel shape.

To create duplex connection in WCF we need to create two contracts: service contract and callback contract. Service contract describes methods client is able to invoke on a service and callback contract describes methods service can invoke on a client.

Since we are creating reverse connection client (R1) will become server and server (R2) will become client. This plays nicely with the idea stated previously that R2 is trying to connect to R1 in regular intervals. Once connection is established R1 service has callback object it can use to invoke methods on client (R2) and what is more important all calls that go through callback object go through already established connection.

So that handles connection between R1 and R2. 