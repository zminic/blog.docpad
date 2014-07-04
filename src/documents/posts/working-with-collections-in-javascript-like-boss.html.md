---
title: "Working with collections in javascript like a boss"
layout: "post"
date: 2013-01-18
summary: "If you ever had to convert one object graph to another you know what pain can that be. In this post I will explain how to use excellent linq.js library to make that work easy."
summaryImage: "/images/posts/linqjs.jpg"
tags: [javascript, programming, collections]
---

If you ever had to convert one object graph to another you know what pain can that be. You had to iterate through different collections, often using nested for loops, you had to filter data, search data, perform sort and similar tasks. This work is boring, I don't like to write a lot of code to do a simple task. It looks ugly and feels the same way.

If you come from .NET world you probably know about [LINQ (Language Integrated Query)](http://en.wikipedia.org/wiki/Language_Integrated_Query). It allows you to do some serious work with collections in query like syntax. Remember SQL? Writing LINQ is just like writing SQL - easy and straight to the point.

The good news is there is a library in javascript that gives you the power of LINQ. Enter [linq.js](http://linqjs.codeplex.com/).

In this article I will show you how to get started with linq.js library and show you a few examples where I found it useful.

## Examples ##

Sample:

```javascript
	"dataset": [
	{
		"seriesname": "2005",
		"color": "B1D1DC",
		"data": [
			{ "value": "27400" },
			{ "value": "29800" }
		]
	},
	{
		"seriesname": "2006",
		"color": "C8A1D1",
		"data": [
			{ "value": "27500" },
			{ "value": "39800" }
		]
	}]
```
	
This JSON sample represents collection of series of one chart library and I'm going to use it to create all examples.

_Create an array with all values in all series_

```javascript
	var result = Enumerable
		.From(dataset)
		.SelectMany("$.data")
		.Select("$.value")
		.ToArray();
```
		
Phew, that was easy. To do that in plain javascript you would need a nested for loop:

```javascript
	var i,j, result = [];
	 
	for(i=0; i < dataset.length; i++)
	{
		for(j=0; j < dataset[i].data.length; j++)
		{
			result.push(dataset[i].data[j].value);
		}
	}
```
	
Which one do you like better?

Now you may think that's not a big deal, both code samples are readable and fairly short, but what if we expand our requirements, for example let's say I want only distinct values sorted descending. You can see now how boring that work would be. In linq.js you would simply do:

```javascript
	var result = Enumerable
		.From(dataset)
		.SelectMany("$.data")
		.Select("$.value")
		.Distinct()
		.OrderByDescending()
		.ToArray();
```
		
_Get maximum value in all series_

```javascript
	var result = Enumerable
		.From(dataset)
		.SelectMany("$.data")
		.Max(function(item){ return parseInt(item.value); });
```
		
_Get series color with the name "2006"_

```javascript
	var result = Enumerable
		.From(dataset)
		.Where("$.seriesname='2006'")
		.Select("$.color")
		.ToArray();
```
		
Or you could alternatively use inline functions:

```javascript
	var result = Enumerable
		.From(dataset)
		.Where(function(item){ return item.seriesname == "2006"; })
		.Select("$.color")
		.ToArray();
```
		
_Get series which contains value 39800_

```javascript
	var result = Enumerable
		.From(dataset)
		.Where(function(item){ 
			return Enumerable
					.From(item.data)
					.Any("$.value == '39800'"); 
		})
		.ToArray();
```
		
_Get average value, from all series except first_

```javascript
	Enumerable
		.From(dataset)
		.Skip(1)
		.SelectMany("$.data")
		.Average(function(item) { return parseInt(item.value); });
```
		
That's it. It wasn't my intention to display all features of library, nor I could (there are a lot of useful functions), but to show you another tool you can put in your belt and use it when needed.

## Summary ##

As you can see this library can be a life saver if you need to do a lot of work with collections. Recently I had to convert one JSON structure to another for a different charting libraries and found this tool indispensable. It kept my codebase small and readable and I used knowledge I have in C#.

Even if you don't know LINQ I encourage you to learn it, and start working with collections like a boss.