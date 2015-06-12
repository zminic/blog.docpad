---
title: "ASP.NET MVC and HTML5 history API"
layout: "post"
date: 2015-06-12
summary: "In this article I'm going to explain how to configure ASP.NET MVC routes to play nice with HTML5 history API."
summaryImage: "/images/posts/html5-history.png"
tags: [ASP.NET, MVC, HTML5, History API]
---

<img src="/images/posts/html5-history.png" title="Html5 history" align="left" />

One way to implement client side navigation in single page apps would be to use HTML5 history API. With this API it is possible to change browser URL without full page reload and also to respond to browser navigation buttons (back and forward).

In this article I'm going to explain how to configure ASP.NET MVC routes to play nice with HTML5 history API.

In my scenario I had a single page app with sections for anonymous and authenticated users. In my navigation mechanism I separated this sections in following way: anonymous users pages have links in format {app root}/anonymous/page1/subpage1, and authenticated users in format {app root}/user/page1/subpage1. This basically means that pages are namespaced (or organized in folders) based on information if user is authenticated or not.

Since in ASP.NET MVC app, default route is in following format {controller}/{action}/{id}, requests to my pages would be routed to anonymous and user controllers. And what I want is to route anonymous/\* links to Home/Login (home controller and login action) and user/\* to Home/Index since this controllers and actions are responsible for application bootstrapping.

To do this I needed to change default route to "pass through" URL if it starts with anonymous or user string, and to define separate routes for this case. This can be achieved with route constraints.

This is my route configuration:

```csharp
routes.MapRoute(
	name: "Default",
	url: "{controller}/{action}/{id}",
	defaults: new { controller = "Home", action = "Index", id = UrlParameter.Optional },
	constraints: new { controller = new HtmlHistoryRouteConstraint() }
);

routes.MapRoute(
	name: "ClientUrlAuthenticated",
	url: "user/{*url}",
	defaults: new { controller = "Home", action = "Index" }
);

routes.MapRoute(
	name: "ClientUrlAnonymous",
	url: "anonymous/{*url}",
	defaults: new { controller = "Home", action = "Login" }
);
```

First route is modified default route with special constraint for controller. This constraint is a class that implements _IRouteConstraint_ interface and there I have logic which disables this route if it encounters anonymous and user strings.

```csharp
public class HtmlHistoryRouteConstraint: IRouteConstraint
{
	public bool Match(HttpContextBase httpContext, Route route, 
		string parameterName, 
		RouteValueDictionary values,
		RouteDirection routeDirection)
	{
		return !values[parameterName].Equals("anonymous") && 
			!values[parameterName].Equals("user");
	}
}
```

The other two routes configure router to go to specified controller and action if it encounters URLs that start with anonymous and user strings.