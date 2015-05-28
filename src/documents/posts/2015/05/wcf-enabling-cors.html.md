---
title: "Adding CORS support to WCF"
layout: "post"
date: 2015-05-27
summary: "Because of the same origin policy javascript from one domain can't invoke service on another domain through AJAX call. Cross origin resource sharing is a mechanism to mitigate this limitation by setting correct headers to allow interaction."
summaryImage: "/images/posts/cors.png"
tags: [WCF, CORS, cross origin, extension, WCF behavior]
---

<img src="/images/posts/cors.png" title="CORS" align="left" />

Because of the [same origin policy](https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy) javascript from one domain can access resource on another domain only through GET request. Usually when we communicate with services we need to use verbs other than GET and sometimes we need to set custom HTTP headers. [Cross origin resource sharing](http://en.wikipedia.org/wiki/Cross-origin_resource_sharing) is a mechanism to mitigate this limitation by setting correct headers to allow interaction.

Basically when javascript tries to communicate with different domain browser will expect server to return appropriate CORS headers or response will not be processed. Also browsers that support CORS will insert "preflight" request before actual request to determine if script has permission to perform action. Preflight request uses OPTIONS verb, defines "Origin" header and does not have body. Server is expected to respond to this request with HTTP response (code 200) with CORS headers and also without any body.

The problem with WCF service is that it doesn't know what to do with preflight request. It is not configured to allow OPTIONS verb and also it doesn't know what headers to send. In this article I will explain how to create WCF behavior which will add support for CORS to the WCF service.

## Configuration ##

First we need a place to store allowed domains with configurations. In this article I will use custom .NET configuration section to do so, but behavior will work with any store (database, plaintext file, etc.). This is what final configuration looks like:

```markup
<CorsSupport>
	<Domain 
		Name="http://somedomain" 
		AllowMethods="POST" 
		AllowHeaders="Content-Type" 
		AllowCredentials="true">
	</Domain>
	<Domain 
		Name="http://anotherdomain" 
		AllowMethods="POST, PUT" 
		AllowHeaders="Content-Type" 
		AllowCredentials="true">
	</Domain>
</CorsSupport>
```

Next I will create an endpoint behavior and attach to it message inspector that will enable CORS support:

## Endpoint behavior to enable CORS support ##

```csharp
public class EnableCorsSupportBehavior: IEndpointBehavior
    {
        public void Validate(ServiceEndpoint endpoint)
        {
            
        }

        public void AddBindingParameters(ServiceEndpoint endpoint, 
			BindingParameterCollection bindingParameters)
        {
            
        }

        public void ApplyDispatchBehavior(ServiceEndpoint endpoint, 
			EndpointDispatcher endpointDispatcher)
        {
            endpointDispatcher.DispatchRuntime.MessageInspectors.Add(
				new CorsEnablingMessageInspector());
        }

        public void ApplyClientBehavior(ServiceEndpoint endpoint, 
			ClientRuntime clientRuntime)
        {
            
        }
    }

    public class CorsEnablingMessageInspector : IDispatchMessageInspector
    {
        public object AfterReceiveRequest(ref Message request, 
			IClientChannel channel, InstanceContext instanceContext)
        {
            var httpRequest = (HttpRequestMessageProperty)request
				.Properties[HttpRequestMessageProperty.Name];

            return new
            {
                origin = httpRequest.Headers["Origin"],
                handlePreflight = httpRequest.Method.Equals("OPTIONS", 
					StringComparison.InvariantCultureIgnoreCase)
            };
        }

        public void BeforeSendReply(ref Message reply, object correlationState)
        {
            var state = (dynamic)correlationState;

            var config = ConfigurationManager.GetSection("customSettings") as CustomSettings;

            if (config == null)
                throw new InvalidOperationException("Missing CORS configuration");

            var domain = config.CorsSupport.OfType<CorsDomain>()
				.FirstOrDefault(d => d.Name == state.origin);

            if (domain != null)
            {
                // handle request preflight
                if (state.handlePreflight)
                {
                    reply = Message.CreateMessage(MessageVersion.None, "PreflightReturn");

                    var httpResponse = new HttpResponseMessageProperty();
                    reply.Properties.Add(HttpResponseMessageProperty.Name, httpResponse);

                    httpResponse.SuppressEntityBody = true;
                    httpResponse.StatusCode = HttpStatusCode.OK;
                }

                // add allowed origin info
                var response = (HttpResponseMessageProperty)reply
					.Properties[HttpResponseMessageProperty.Name];
                response.Headers.Add("Access-Control-Allow-Origin", domain.Name);

                if (!string.IsNullOrEmpty(domain.AllowMethods))
                    response.Headers.Add("Access-Control-Allow-Methods", domain.AllowMethods);

                if (!string.IsNullOrEmpty(domain.AllowHeaders))
                    response.Headers.Add("Access-Control-Allow-Headers", domain.AllowHeaders);

                if (domain.AllowCredentials)
                    response.Headers.Add("Access-Control-Allow-Credentials", "true");
            }
        }
    }
```

The idea behind this implementation is to hook up to every request made to the WCF service, and to inspect its headers. If the verb invoked is "OPTIONS" then we know that this is a preflight request and we completely change server response to comply to the expected response for preflight. If request is not preflight then we read configuration and set appropriate headers if we have origin match.

## Source code ##

The complete source code with service and tests can be found at my [github repository](https://github.com/zminic/wcf-cors-support).

## Summary ##

In this article I briefly explained the problem that arises when someone tries to invoke WCF service from javascript served on a different domain. The solution I propose leverages WCF extension point that inspects incoming and outgoing messages and modifies response appropriately to support CORS. In this article I included the gist of solution, for any details regarding to service bindings, endpoints and other configuration please check source code.