---
title: "Manage cross-cutting concerns using decorator design pattern"
layout: "post"
date: 2012-09-20
summary: "If you don’t pay attention to an application architecture at the beginning you are likely to end up with a complex product that is hard to extend and maintain. A problem often overlooked is the proper management of cross-cutting concerns."
summaryImage: "/images/posts/decorator_pattern.jpg"
tags: [c#, patterns & practices, programming]
---

> Making the simple complicated is commonplace; making the complicated simple, awesomely simple, that’s creativity.
>
> Charles Mingus

If you don’t pay attention to an application architecture at the beginning you are likely to end up with a complex product that is hard to extend and maintain. A problem often overlooked is the proper management of cross-cutting concerns.

[Cross-cutting concerns](http://en.wikipedia.org/wiki/Cross-cutting_concern) are simply aspects of the program that are used throughout whole application. Some examples include logging, caching, authorization and transaction management. Technique often employed when dealing with cross-cutting concerns is [Aspect Oriented Programming (AOP)](http://en.wikipedia.org/wiki/Aspect-oriented_programming).

AOP is not subject of this post and I will not go into details on how to use it to manage cross-cutting concerns. Instead I will focus on alternate approach you might consider when working on small projects – [decorator design pattern](http://en.wikipedia.org/wiki/Decorator_pattern).

Let’s start with an example:

```csharp
	public interface ILayoutService
	{
		void LoadWidget(string name);
	}

	public class LayoutService: ILayoutService
	{
		readonly Logger _logger;
		readonly AuthorizationService _authService;

		public LayoutManager()
		{
			_logger = new Logger();
			_authService = new AuthorizationService();
		}

		public void LoadWidget(string name)
		{
			if (!_authService.IsUserAuthorized)
				throw new Exception("Not authorized!");

			_logger.Log("Widget loading started!");

			// widget loading logic

			_logger.Log("Widget loading ended!");
		}
	}

	var service = new LayoutService();
```

In the example above I’ve created the simple imaginary layout management service. It defines only one method that performs widget loading. However the presented design has few flaws:

1. It violates [single responsibility principle](http://en.wikipedia.org/wiki/Single_responsibility_principle). The class performs authorization, logging and widget loading. It will have to change if either authorization or logging class changes.
2. It is not very readable. The method contains a lot of noise around actual business logic.
3. To test this method I would have to mock logging and authorization services.

Let’s see now an improved example that uses the decorator design pattern:

```csharp
	public interface ILayoutService
	{
		void LoadWidget(string name);
	}

	public class LayoutService: ILayoutService
	{
		public void LoadWidget(string name)
		{
			// widget loading logic
		}
	}

	public class LayoutServiceDecorator: ILayoutService
	{
		ILayoutService _service;

		public LayoutServiceDecorator(ILayoutService _service)
		{
			_service = service;
		}

		public virtual void LoadWidget(string name)
		{
			_service.LoadWidget(name);
		}
	}

	public class LayoutServiceLoggingDecorator: LayoutServiceDecorator
	{
		readonly Logger _logger;

		public LayoutServiceLoggingDecorator(ILayoutService layoutService) :
			base(layoutService)
		{
			_logger = new Logger();
		}

		public override void LoadWidget(string name)
		{
			_logger.Log("Widget loading started!");

			base.LoadWidget(name);

			_logger.Log("Widget loading ended!");
		}
	}

	public class LayoutServiceAuthDecorator: LayoutServiceDecorator
	{
		readonly AuthorizationService _authService;

		public LayoutServiceAuthDecorator(ILayoutService layoutService) :
			base(layoutService)
		{
			_authService = new AuthorizationService();
		}

		public override void LoadWidget(string name)
		{
			if (!_authService.IsUserAuthorized)
				throw new Exception("Not authorized!");

			base.LoadWidget(name);

			_logger.Log("Widget loading ended!");
		}
	}

	var service = new LayoutServiceAuthDecorator(
		new LayoutServiceLoggingDecorator(new LayoutService()));
```

The code above looks bigger than the one we started with but from the design perspective it’s much better. Look at the LayoutService class. Now it only contains business logic, it is much readable. Also note that there are no dependencies on authorization and logging services, those dependencies are not responsibility of LayoutService class but its creator. User of the class can decide at runtime if it will attach additional behaviors to the service and in what order.

Also the presented solution is test friendly, we can only test core service class without any decorators attached.

It becomes obvious that this solution is not very good for large projects since it requires few decorator classes per class, also there is a lot of duplicated code in those decorators which will have to change if cross-cutting concerns change. In that situation I would rather use a full blown AOP framework.