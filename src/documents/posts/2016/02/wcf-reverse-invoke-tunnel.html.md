---
title: "WCF Reverse invoke tunnel"
layout: "post"
date: 2016-02-19
summary: "In a typical multi-layer system client layer connects to a service layer and retrieves information. But what if we need to reverse that flow?"
summaryImage: "/images/posts/wcf-reverse-invoke-small.png"
tags: [WCF, Reverse invoke, WCF behavior, WCF duplex]
---

In a typical multi-layer system client layer connects to a service layer and retrieves information. But what if we need to reverse that flow?

Recently we had a request from client's security department to change our architecture so that web application deployed in DMZ zone never directly invokes our middleware application deployed in intranet zone. Between these zones administrators will install firewall that will block all incoming calls from DMZ to intranet.

In this article I will describe the solution I designed for this specific problem. Although I cannot post source code, since this is company's project, I will do my best to explain general idea behind solution so anyone with similar problem can follow guidelines to implement working solution.

Since we are using WCF for all our services first we tried to find existing solution to the problem and to find out if maybe WCF had feature we could use. To our surprise there was no existing .NET solution for this problem nor WCF feature we could use. So we decided to roll our own.

We agreed that solution should meet these requirements:

1. Solution must be transparent to the current architecture. In other words apps from DMZ and intranet zones must not change. Ideally only configuration should change. Developers continue to use WCF technology for communication between different layers in the same way as if there was no reverse connection requirement. Administrators will configure reverse connection during deployment.
2. Solution must support WCF security features over reverse connection.
3. Solution must have similar performance as direct communication in terms of speed and scalability.
4. Solution must be highly available.

## Architecture ##

After considering few options I proposed architecture with custom application tunnel between DMZ and intranet zones. This architecture includes two intermediary routers, in further text R1 and R2, that form the application tunnel. Messages sent to the R1 router will be forwarded to R2 router using reverse connection. After that R2 router must route message to the destination service.

<img class="img-responsive" src="/images/posts/wcf-reverse-invoke.png" title="Proposed architecture" />

The following steps describe general flow of communication:

1. Router R1 starts.
2. Router R2 starts and tries to connect to R1 in regular intervals. First established connection is called management connection.
3. R1 can use management connection to ask R2 to create more connections (if needed for high load).
4. Additional connections from R2 are stored in custom connection pool.
5. When incoming request arrives web application forwards it to the R1 router. R1 uses connection from pool to send request to the R2. R2 routes request to the destination.

Basic idea behind reverse connection is to reuse connection already opened by service instead of establishing new one. Of course, this is possible only by using state-full protocol like TCP. If we want to translate that idea to WCF we can use WCF duplex binding or more specific - duplex channel shape.

To create duplex connection in WCF we need to create two contracts: service contract and callback contract. Service contract describes methods client is able to invoke on a service and callback contract describes methods service can invoke on the client.

Since we are creating reverse connection client (R1) will become server and server (R2) will become client. This plays nicely with the idea stated before that R2 is trying to connect to R1 in regular intervals. Once connection is established R1 service has callback object it can use to invoke methods on client (R2) and what is more important all calls that go through callback object go through already established connection.

 ### DMZ Router ###
 
Router in DMZ zone (R1) has following responsibilities:

* It acts as a server for all incoming calls, for all clients.
* It acts as a server for connections from intranet zone and manages connections using connection pool.
* It routes incoming calls to intranet router.
* It provides health check information for high availability scenario.

#### Routing service ####

As an entry point to the tunnel R1 router must expose endpoints for all needed WCF bindings. For example if one app from DMZ connects to app in intranet using binding without security (such as basic http binding) then R1 router must provide similar endpoint as well. R1 router hosts routing WCF service which handles incoming calls, this service can have multiple endpoints as described before with different bindings.

Routing service has very simple contract with single method that handles all messages:

```csharp
[ServiceContract]
public interface IRouterContract
{
	[OperationContract(Action = "*", ReplyAction = "*")]
	Task<Message> ProcessMessageAsync(Message message);
}
```

Implementation of this method takes available connection from connection pool and forwards incoming message.

#### Registration service ####

Through the registration service R1 router accepts connections from intranet router. As stated before shape of this connection is duplex.

Contracts for registration service are following:
 
 ```csharp
 [ServiceContract]
public interface IRegistrationCallbackContract
{
	[OperationContract(IsOneWay = true)]
	Task MakeNewConnectionAsync();

	[OperationContract(IsOneWay = true)]
	void Close();

	[OperationContract(Action = "*", ReplyAction = "*")]
	Task<Message> SendMessageAsync(Message msg);
}


[ServiceContract(CallbackContract = typeof(IRegistrationCallbackContract))]
public interface IRegistrationContract
{
	[OperationContract]
	Task Connect();

	[OperationContract]
	void Ping();
}
 ```
 
As you can see client (R2) is able to connect and to ping this service, on the other hand server (R1) is able to request new connection, close existing connection and forward message.
 
#### Health check service ####

In high availability scenario, which will be described later, load balancer will have to know health of the application tunnel before forwarding request to it. It is not enough that R1 service is available, but also that R1 has established connection to R2.

For this purporse R1 service exposes simple service endpoint with webHttpBinding, so health check comes down to:
 
 ```
request:
 
GET http://localhost:8085/healthcheck 
 
response:
 
"ManagementConnection: ACTIVE" 
 ```
 
Behind the scenes R1 service checks state of current management connection.
 
 #### Connection pooling ####
 
Since WCF doesn't provide any mechanism to manage callbacks we have to create our own. When connection arrives from R2 it is stored in custom made connection pool.
 
Creating connection pool is not an easy task, it has to:
 
 * Efficiently manage multi-threaded access
 * Automatically maintain minimum and maximum number of configured connections
 * Determine when additional connections are needed and to make request for them
 * Determine when connection in pool is closed and to replace it with new connection
 * Distribute load evenly on all connections
 
In out implementation we used .NET BlockingCollection class as a backing store for connections. This collection is thread safe and has handy methods for blocking thread until new connection becomes available. Distribution of load is handled by getting connection from the pool and then returning it back at the end of the pool. Since BlockingCollection is by default using queue structure behind the scenes this simulates round robin scheduling.

### Intranet router ###

On the other end of the tunnel R2 router has following responsibilities:

* Periodically monitor and maintain duplex connection to the R1 router
* Route incoming message from R1 router to the destination

When incoming message arrives through duplex connection this router must make a decision where to send it. This decision is made based on message headers. There are two possibilities:

1. Route message based on the SOAP action header
2. Route message based on a custom header

We have separate configuration section for this configuration. Example:

```markup
<duplexRouter>
<Routes>
	<Route SoapActionPart="ITestServiceProxy" EndpointName="targetEndpoint" />
	<Route ClientRouteName="test"" EndpointName="targetEndpoint2" />
</Routes>
</duplexRouter>
```

Here we configured that if soap action header contains "ITestServiceProxy" then we route it to endpoint named "targetEndpoint". similarly we can specify custom header "ClientRouteName" to any value we want and then make a decision based on that value.

For custom header scenario to work we must specify this header in endpoint where we call R1 router from DMZ application. For example in this way:

```markup
<endpoint address="net.tcp://localhost:8082/router" binding="netTcpBinding"
	contract="DuplexRouterCommon.Test.ITestServiceProxy">
<headers>
	<ClientRouteName>test</ClientRouteName>
</headers>
</endpoint>
```

## High availability setup ##

In the architecture presented above application tunnel (R1 and R2 pair) present single point of failure. For example if either R1 or R2 stops working the whole system is down. To mitigate this concern high availability architecture for reverse connection is introduced.

<img class="img-responsive" src="/images/posts/wcf-reverse-invoke-high-availability.png" title="High availability scenario" />

In this architecture there are multiple (at least two) load balanced application tunnels (R1 and R2 pairs).

Every router in DMZ zone supports health checks in which it can return information if connection with router server in intranet zone is established. In this way traffic is routed to healthy routers when any of R1 or R2 routers stops working.

Network load balancer (NLB) distributes traffic to multiple R1 routers based on health check status. For example if one router looses connection then future calls will be directed to different healthy routers.

For this to work NLB software must support application health check monitoring, and most of layer 7 load balancers do. List of compatible load balancers include: IIS ARR, Nginx plus, freeloadbalancer.com.

To achieve high availability all routers must be deployed to separate machines (virtual or physical), so that in the case of one machine downtime all other routers continue working.

## Deployment ##

Duplex routers are hosted as self hosted WCF applications. We host them in console application in development environment and as a windows service in production. In this way we can easily debug services. This is made extremely easy by excellent <a href="http://topshelf-project.com/">top-shelf project</a> that I recommend.

## Summary ##

Creating this solution has been an incredible journey. I have really enjoyed and learned a lot about internals of WCF. This kind of projects remind me why I love my job.

If you have any questions about this solution or specific implementation details please feel free to ask in comments.