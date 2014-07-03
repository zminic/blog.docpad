---
title: "Functional inheritance in javascript"
layout: "post"
date: 2012-11-13
summary: "People often ask me how do I do inheritance in javascript. Can javascript do inheritance? Even if javascript has classes? In this post I will try to give answers to those questions and present inheritance pattern I use frequently in javascript."
summaryImage: "/images/posts/inheritance.jpg"
tags: [javascript, programming, patterns & practices]
---

People often ask me how do I do inheritance in javascript. Can javascript do inheritance? Even if javascript has classes?

In this post I will try to give answers to those questions and present inheritance pattern I use frequently in javascript.

## Are there classes in javascript? ##

The short answer is no. In javascript the functions are a first class citizens and there is no concept of a class.

But before I explain what we can do about it let's first ask ourselves one important question: why do we need classes? Oh, that's easy, classes organize our code and promote code reuse. Knowing that we can improve our question: "Are there tools in javascript to help us organize our code and to promote code reuse?". Now this is much better question and the answer is yes, we can use design patterns to emulate constructs that are missing in language specification.

Although in ECMAScript 6 specification there is a "class" keyword, note that this hardly changes anything from the language point. Language is still functional and classes are merely a syntatic sugar.

## Inheritance patterns ##

So if there are no classes can there be an inheritance? Again remember to think in terms of functionality rather then concepts you know from other programming languages. There are design patterns which we can exploit to get functionality of inheritance.

There are two well known inheritance design patterns in javascript (at least for me): Pseudoclassical and Functional. The terminology comes from Douglas Crockford's book "Javascript - The Good Parts" which I recommend reading.

The Pseudoclassical inheritance pattern is not the subject of this article, it's much more used then the functional pattern and you can find example of it almost everywhere.

## Functional inheritance pattern ##

n the functional inheritance pattern we create our "classes" with functions that return objects. The pattern is similar and probably comes from the module design pattern. The properties you attach to the returning object are class public interface. Functions and properties you define inside function, but not as a part of the returning object, are private members accessible because of closure and invisible because they were not returned.

See the following example:

### Defining a class ###

```javascript
	function TestClass(/*arguments*/)
	{
		// return object
		var obj = {};
		 
		var privateField;
		 
		function privateFunction() {}
		 
		obj.publicField = "";
		 
		obj.publicFunction = function() {};
		 
		// construction logic here
		 
		return obj;
	}
```
	
We have defined class function which returns object. Properties and functions defined on that object become public interface and the rest is private. One thing is important to note here, private properties are truly private and there is no way to force class to give up its secrets.

Ok, how do we inherit that class? See the following example:

### Inheritance ###

```javascript
	function TestClassSpecific(/*arguments*/)
	{
		// initial object is instance of our test class
		var obj = TestClass();
		 
		// save reference to parent class function
		var super_publicFunction = obj.publicFunction;
		 
		obj.publicFunction = function()
		{
			// call parent class function
			super_publicFunction();
		};
		 
		// construction logic here
		 
		return obj;
	}
```
	
A few things to note here: our return object is instance of parent class, because of that fact it contains all methods defined on parent class. Second if we want to override parent class function we have to save reference to that function first, then we can easily invoke parent function inside our override.

It's simple as that. Very neat and easy on eyes. But wait it gets even better, you can also have protected members:

### Protected members ###

```javascript
	function TestClass(my)
	{
		var obj = {};
		 
		my = my || {};
		 
		my.protectedField = "";
		 
		my.protectedFunction = function(){};
		 
		return obj;
	}
	 
	function TestClassSpecific()
	{
		var my = {},
			obj = TestClass(my);
			 
		return obj;
	};
```
	
This one may be confusing at first but makes perfect sense once you understand it. If you take object as a argument of parent class and attach properties and functions to that objects then those fields become protected, shared secrets between parent and child classes. In the example above TestClassSpecific **can** access protectedField and protectedFunction, but code outside that class can't.

Although this inheritance pattern looks too good to be true you need to understand implications of its usage:

### Pros ###

* Easy on eyes. This pattern is very straightforward and easy for beginners to learn.
* Offers truly private and protected members.
* Protects against common javascript pitfalls, specifically if you forget to specify "new" keyword during class creation or if you are using "this" keyword inside functions.

### Cons ###

* Requires more memory than Pseudoclassical inheritance pattern. With every new instance of a class memory is reserved for all functions and fields inside that class.
* Types cannot be tested using "instanceof" keyword.
* Javascript minimizers might not perform as good as with Pseudoclassical pattern as there is no way for minimizer to safely rename members of parent class.

### Conclusions ###

So, here we have some strong points both for and against functional inheritance pattern and one question comes by itself: Should I use it? There is no unique answer to that question, it depends on your situation. Carefully consider both pros and cons and decide if this pattern is good for you.

I'm successfully using it on large project (about 100000 lines of javascript code) with nothing but success. I choose it mainly because of the small learning curve - the ease with which I can explain inheritance to new developers.

What do you think? Does it work for you?