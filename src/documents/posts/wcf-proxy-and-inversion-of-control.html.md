---
title: "WCF Proxy and inversion of control"
layout: "post"
date: 2015-05-18
summary: "WCF proxy handling is not as transparent as we would like it to be. We need to remember to correctly close the channel once we do not need it and furthermore we need to keep track of the channel state. If we add IoC to the mix we are bound to get some trouble."
summaryImage: "/images/posts/wcf-proxy-ioc.png"
tags: [wcf, wcf proxy, inversion of control, dependency injection]
---

WCF proxy handling is not as transparent as we would like it to be. We need to remember to correctly close the channel once we do not need it and furthermore we need to keep track of the channel state. If we add IoC to the mix we are bound to get some trouble.

## Simple proxy call ##

With WCF proxy Microsoft is trying to abstract away dealing with the underlying communication infrastructure and to give you the feeling that you are working with local classes and interfaces, but so far it does a poor job. Recommended pattern from MSDN regarding correct call is following:

```csharp
CalculatorClient wcfClient = new CalculatorClient();
try
{
	Console.WriteLine(wcfClient.Add(4, 6));
	wcfClient.Close();
}
catch (TimeoutException timeout)
{
	// Handle the timeout exception.
	wcfClient.Abort();
}
catch (CommunicationException commException)
{
	// Handle the communication exception.
	wcfClient.Abort();
}
```

It is clear that you must know you are dealing with underlying communication infrastructure if you look at this code. Also try to imagine writing above code for every single service call if you have few hundred service methods, it is not pretty.

## Adding IoC to the mix ##

Things are bad as they are, but if you try to add IoC container to the mix they get worse. If you define proxy to be a class level dependency injected by IoC container you are in trouble. Now different methods inside your class can call proxy, but if one method closes proxy, another cannot use it, it must be recreated. And how would you go about closing proxy since you are declaring proxy by its interface type which does not have close and abort methods?

Example:

```csharp
public class Calculation
{
	private readonly ICalculatorClient _client;

	public Calculation(ICalculatorClient client)
	{
		_client = client;
	}

	public int Add(int x, int y)
	{
		var result = _client.Add(x, y);
		// how can we close this proxy? Maybe try to cast to ICommunicationObject?

		return result;
	}

	public int Multiply(int x, int y)
	{
		// we cannot call method on already closed proxy
		var result = _client.Multiply(x, y);

		return result;
	}
}
```

No we have too much things to think about and we didn't even get to more complex use cases like reusing same proxy instance across different classes (with different lifetime manager).

## Alternatives ##

As usual if Microsoft doesn't provide functionality we need to come up with alternatives and hope that things get fixed in next version of .NET framework.

Some alternatives (to Microsoft's recommended approach) include:

*	[ChannelAdam WCF client library](https://devzone.channeladam.com/articles/2014/09/how-to-easily-call-wcf-service-properly/). Very good description of the problem and possible solutions. Available as NuGet package.
*	[WCFServiceProxy](https://github.com/azzlack/WCFServiceProxy). Available as NuGet package.

While these and similar libraries mitigate problems with proxy closing and writing boilerplate code, they still fail to abstract WCF proxy so you can use it as any other .NET class or interface. These libraries create their own abstractions like service factories and proxy wrappers and force you to write code their way (to use their abstractions). I wondered if there is a better way, can we achieve the goal to use WCF proxy as any other .NET class?

Yes we can! With the help of aspect oriented programming and concept called interception. 

## My solution ##

I think that most of IoC containers have concept of interception - the ability to define certain interceptors (aspects) that can change behavior of your class once configured to do so. You can think about them as generic decorators created to fit any class and they are usually created to address cross cutting concerns. In my example I'm using Unity container and Unity.Interception extension.

<img src="/images/posts/wcf-proxy-ioc.png" />

The idea is to create interceptor which will intercept every proxy method call and correctly create new proxy object, invoke method and perform cleanup (close proxy).

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.ServiceModel;
using Microsoft.Practices.Unity;
using Microsoft.Practices.Unity.InterceptionExtension;

namespace Test.Wcf
{
    public class WcfProxyInterceptor: IInterceptionBehavior
    {
        private readonly IUnityContainer _container;

        public WcfProxyInterceptor(IUnityContainer container)
        {
            _container = container;
        }

        public IMethodReturn Invoke(IMethodInvocation input, GetNextInterceptionBehaviorDelegate getNext)
        {
            // create new instance of proxy (because previous call might have closed proxy)
            var proxy = _container.Resolve(input.MethodBase.DeclaringType, "Basic") 
				as ICommunicationObject;

            // ensure that we got ICommunicationObject
            if (proxy == null)
                throw new InvalidOperationException("Interception attempted on non wcf proxy interface");

            var success = false;

            try
            {
                var args = input.Arguments.Cast<object>().ToArray();

                // invoke method on new proxy
                var result = input.MethodBase.Invoke(proxy, args);

                proxy.Close();
                success = true;

                return input.CreateMethodReturn(result, args);
            }
            catch (Exception ex)
            {
                if (!success)
                    proxy.Abort();

                return input.CreateExceptionMethodReturn(ex);
            }
        }

        public IEnumerable<Type> GetRequiredInterfaces()
        {
            return new []{ typeof(ICommunicationObject) };
        }

        public bool WillExecute
        {
            get { return true; }
        }
    }
}
```

The reasoning behind this code is as follows:

Since we plan to close proxy after every call we cannot reuse intercepted proxy because it will be in closed state. Idea is to create new instance of proxy, call method, return result and close proxy.

This is not a trivial task and my first naive implementation was to use Activator.CreateInstance to do so, but then I had a use case which required changing proxy object after creation (to add custom endpoint extensions at runtime). At that point it became clear to me that I need to offload proxy creation to some other class. I decided to transfer that responsibility to the container since container is already responsible for class instantiation. In Unity you can have multiple registrations to the same interface if you name them. I decided to always create basic registration (with name Basic) which is tasked to create proxy object, and another registration without name which will perform interception.

So Unity registration for single service would look like this:

```csharp
container = new UnityContainer();

container.AddNewExtension<Interception>();

// basic creation
container.RegisterType<ICalculatorClient, CalculatorClient>("Basic", new InjectionConstructor());

// intercepted creation
container.RegisterType<ICalculatorClient, CalculatorClient>(
	new InjectionConstructor(),
	new Interceptor<InterfaceInterceptor>(),
	new InterceptionBehavior<WcfProxyInterceptor>());
```

So, to return to the main flow, we create new proxy object with container and we cast it to ICommunicationObject since we expect WCF proxy here.

Next we perform method call on proxy using MethodBase method definition. It is incredibly handy that invoke method accepts object on which to call method. Since we already have full method definition we can simply invoke it on our new proxy object.

After that we perform the cleanup and return result.

## Possible improvements ##

*	Demonstrated solution always closes proxy after method call creating additional overhead. It is generally recommended to reuse proxy, and we could improve this solution by storing proxy instance in local variable (it's lifetime would be the same as lifetime of intercepted instance) and then to look at proxy state to decide if we need to create new instance.
*	There is a minor inconvenience that you need two registrations for single interface in order to perform this setup (basic and intercepted). For simple use cases where there is no need for complete control over proxy creation we could remove this requirement, but for advanced scenario I think that this is good solution. Maybe we could try to resolve "Basic" registration, and if it doesn't exist we could fallback to default creation, in that way we would get best from both worlds.
*	This solution works with async methods by default, but I'm not sure if all use cases are covered. As per my tests after firing async call and immediately closing proxy, it won't be closed until async method returns, so we do not need to change code.

## Working example ##

You can find working example in my [github repository](https://github.com/zminic/wcf-proxy-interception).