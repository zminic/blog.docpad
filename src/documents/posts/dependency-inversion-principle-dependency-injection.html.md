---
title: "Dependency Inversion Principle, Dependency Injection and Inversion Of Control"
layout: "post"
date: 2012-09-13
summary: "I’m a big fan of Dependency Injection pattern since it allows me to create more testable, maintainable and loosely coupled components. While it is easy to apply this pattern if you’ve seen some code samples you need more time to understand principles and terms around this pattern. In this article I will try to illustrate differences between those terms and explain how they come to work together."
summaryImage: "/images/posts/dependency_injection.jpg"
tags: [c#, patterns & practices, programming]
---

I’m a big fan of Dependency Injection pattern since it allows me to create more testable, maintainable and loosely coupled components. While it is easy to apply this pattern if you’ve seen some code samples you need more time to understand principles and terms around this pattern. In this article I will try to illustrate differences between those terms and explain how they come to work together.

I will use well known car/engine example in this article but any example with dependency will do. All examples are written in C# language.

Let’s first define few example classes:

```csharp
public class Engine {}

public class Car
{
	private Engine _engine;

	public Car()
	{
		_engine = new Engine();
	}
}
```

n the example above we can see that Car (higher level component) depends on Engine (lower level component). At some point we may need to make car more reusable, for example to be able to work with different engines. It’s obvious that example above isn’t good enough since our Car class creates concrete Engine inside its constructor. How can we tackle that problem? By applying Dependency Inversion Principle (DIP).

## Dependency Inversion Principle ##

DIP principle simply states that higher level modules should not depend on lower level modules but both should depend on abstractions. Higher level module should also own this abstraction effectively now making lower level module depend on that abstraction and thus depend on higher level module.

Example:

```csharp
public interface IEngine {}

public class Engine: IEngine {}

public class Car
{
	private IEngine _engine;
}
```

In this example we can see that our Car now depends on abstraction rather then concrete Engine type, also concrete Engine implements our abstraction which must be packaged with Car to satisfy DIP principle. Another way of saying this would be that abstraction should represent Car needs not Engine possibilities.

In this example I omitted Engine creation part on purpose since DIP principle doesn’t state exactly how dependencies should be created. Actually we can create them in few different ways, by using Dependency injection (DI), Service location or Factory pattern.

And so we came to DI pattern which is the way to facilitate the run-time provisioning of the chosen low-level component implementation to the high-level component.

## Dependency Injection pattern ##

DI pattern deals with the place where dependencies are created. In DI pattern dependency creation is not responsibility of dependent class but rather of its creator.

In the simplest form dependencies are injected through class constructor or by setting class properties.

Example:

```csharp
public interface IEngine {}

public class Engine: IEngine {}

public class Car
{
	private IEngine _engine;

	public Car(IEngine engine)
	{
		_engine = engine;
	}
}
```

In this example we can see that concrete Engine type is being injected into Car class through constructor. Car class is not any more responsible of Engine creation meaning that concrete Engine implementation can be injected at runtime.

Advantages of using this pattern are following:

1. It promotes loosely coupling of components.
2. It makes components testable because at test time we can mock out everything that is not part of our test.
3. It allows runtime resolution of dependencies (configuration).

Only one more thing left and that is the way we create our dependent class. We can simply instantiate all dependencies and inject them to dependent class at the time of creation.

```csharp
var engine = new Engine();
var car = new Car(engine);
```

As we can see this method includes boilerplate code in every place where we need to create our dependent class (Car). It gets even worse if dependency (Engine) has dependencies of its own and so on.

We have applied nice pattern with a lot of advantages and now we want to further improve it by removing boilerplate code. To facilitate DI we can use Inversion of control container.

## Inversion of control ##

oC container is responsible of object creation providing all necessary dependencies on the way. To do this it must know about all abstractions and all concrete types to use for that abstractions. To work with IoC container we must configure it first.

In the following example I will use Microsoft Unity container syntax.

Configuration:

```csharp
var container = new UnityContainer()
	.RegisterType<IEngine, Engine>();
```

With the code above we have configured container to resolve IEngine abstraction with concrete Engine class. We could also configure container using configuration files making it possible to change how application works without compilation.

Resolution:

```csharp
var car = container.Resolve<Car>();
```

Resolve method above will create our Car object and it will automatically supply correct Engine in its constructor.

Complete example:

```csharp
public interface IEngine {}

public class Engine: IEngine {}

public class Car
{
	private IEngine _engine;

	public Car(IEngine engine)
	{
		_engine = engine;
	}
}

var container = new UnityContainer()
	.RegisterType<IEngine, Engine>();

var car = container.Resolve<Car>();
```

Our goal is complete. Now we can use our car with different engines. Also now we have loosely coupled components easy to test and maintain.