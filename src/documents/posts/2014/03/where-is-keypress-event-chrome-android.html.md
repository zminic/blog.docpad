---
title: "Where is keypress event in chrome for Android?"
layout: "post"
date: 2014-03-19
summary: "This one was a surprise. Chrome for Android doesn't support keypress event."
summaryImage: "/images/posts/86416691_4c7286fa9b_m.jpg"
tags: [javascript, programming, quirks]
---

<img class="img-responsive" src="/images/posts/86416691_4c7286fa9b_m.jpg" align="left" />

This one was a surprise. Chrome for Android doesn't support keypress event.

If you are writing mobile applications in web technologies you probably had a need to prevent users to enter some characters to input fields. For example you might have field where you expect only numbers. In this case I use keypress event to test if input character is valid and return false if it's not. In desktop browsers and most mobile browsers this works as expected but in chrome for Android there is no keypress event. Reason for this could be that keypress event is deprecated as outlined here.

My next thought was to try to slightly modify code and use keydown event, but it turned out to be problem also. I found out that there is no way on some devices (Nexus 4) to get pressed character, e.which and e.keyCode are both undefined or 0, always.

Next I started searching web for any workaround, but I could find none, and I finally decided to try to work on input field value rather then on single character.

In this post I will show you how I cheated on keyboard events and managed to implement same functionality without help of e.which and e.keyCode.

## Before ##

Let me first show you jQuery plugin that I used for input filtering with keypress event:

```javascript
	$.fn.blockInput = function (options)
	{
		this.filter('input,textarea')
			.keypress(function (e)
			{
				var char = String.fromCharCode(e.which),
					regex = new RegExp(options.regex);
	 
				return regex.test(char);
			});
	 
		return this;
	};
	 
	$('#test').blockInput({ regex: '[0-9|A-Z]'});
```
	
You can see it in action in this [fiddle](http://jsfiddle.net/zminic/dJnGY/).

## After ##

This is updated plugin that works without keypress event:

```javascript
	$.fn.blockInput = function (options) 
	{
		// find inserted or removed characters
		function findDelta(value, prevValue) 
		{
			var delta = '';
	 
			for (var i = 0; i < value.length; i++) {
				var str = value.substr(0, i) + 
					value.substr(i + value.length - prevValue.length);
				 
				if (str === prevValue) delta = 
					value.substr(i, value.length - prevValue.length);
			}
	 
			return delta;
		}
	 
		function isValidChar(c)
		{
			return new RegExp(options.regex).test(c);
		}
	 
		function isValidString(str)
		{
			for (var i = 0; i < str.length; i++)
			if (!isValidChar(str.substr(i, 1))) return false;
	 
			return true;
		}
	 
		this.filter('input,textarea').on('input', function ()
		{
			var val = this.value,
				lastVal = $(this).data('lastVal');
	 
			// get inserted chars
			var inserted = findDelta(val, lastVal);
			// get removed chars
			var removed = findDelta(lastVal, val);
			// determine if user pasted content
			var pasted = inserted.length > 1 || (!inserted && !removed);
	 
			if (pasted)
			{
				if (!isValidString(val)) this.value = lastVal;
			} 
			else if (!removed)
			{
				if (!isValidChar(inserted)) this.value = lastVal;
			}
	 
			// store current value as last value
			$(this).data('lastVal', this.value);
		}).on('focus', function ()
		{
			$(this).data('lastVal', this.value);
		});
	 
		return this;
	};
	 
	$('#test').blockInput({ regex: '[0-9A-Z]' });
```
	
And corresponding [fiddle](http://jsfiddle.net/zminic/8Lmay/).

The key difference is that latter plugin uses oninput event and works on whole input value rather than single character. It also prevents pasting invalid characters.

To be able to inspect changed value I first had to be able to distinguish current from previous input field value. This is done with custom data property bound to element. Plugin sets this property to current field value on focus and then updates that value after input event finishes. That way I could use element value as current value and "lastVal" property for previous value.

Example:

```javascript
	this.filter('input,textarea').on('input', function ()
	{
		// Filtering code
		 
		$(this).data('lastVal', this.value);
	}).on('focus', function ()
	{
		$(this).data('lastVal', this.value);
	});
```
	
Next task was to find out what characters were inserted/removed/pasted. At first it seemed like trivial task to do, simply get last character of input field and filter that value. But then it became obvious that user can insert text anywhere, not necessarily at the end, and then "findDelta" function was born.

```javascript
	function findDelta(value, prevValue) 
	{
		var delta = '';
	 
		for (var i = 0; i < value.length; i++) {
			var str = value.substr(0, i) + 
				value.substr(i + value.length - prevValue.length);
			 
			if (str === prevValue) delta = 
				value.substr(i, value.length - prevValue.length);
		}
	 
		return delta;
	}
```
	
Idea here is to find inserted characters by using information we already have: value, previous value and inserted text length which you get if you subtract lengths of value and previous value.
When we know inserted text length we can start searching for it by sequentially removing pairs of characters until value becomes same as previous value, then removed characters become delta.

It turns out that finding removed characters is directly opposite: start from previous value, insert characters sequentially until you get current value, in other words switch places of input arguments.

To find out if user pasted content we test if number of inserted characters is bigger then one or if there are no inserted or removed characters (in other words user pasted over existing text not changing resulting text length).

```javascript
	// get inserted chars
	var inserted = findDelta(val, lastVal);
	// get removed chars
	var removed = findDelta(lastVal, val);
	// determine if user pasted content
	var pasted = inserted.length > 1 || (!inserted && !removed);
```
	
Finally if user pasted content we need to check whole input value character by character (because regex is for single characters), if user removed something we don't need to test, and if user inserted single character we need to test only that character.

## Summary ##

If you think about it, it's funny how finding workarounds becomes normal when dealing with web standards, but it's encouraging to know that they are possible and that at the end of the day we (web developers) emerge as winners.