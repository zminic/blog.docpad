---
title: "ASP.NET MVC Bundling and Minification with RequireJS"
layout: "post"
date: 2014-06-24
summary: "It’s hard to say what are best practices for handling code minification if you are using ASP.NET MVC and RequireJS library. You could use built-in optimization features of ASP.NET on one side and RequireJS optimization tool on the other side. In this article I will describe one potential setup."
summaryImage: "/images/requirejs.png"
---

# ASP.NET MVC Bundling and Minification with RequireJS #

<img src="/images/requirejs.png" align="left" style="padding: 0 15px 15px 0" />

It’s hard to say what are best practices for handling code minification if you are using ASP.NET MVC and RequireJS library. You could use built-in optimization features of ASP.NET on one side and RequireJS optimization tool on the other side.

RequireJS has a really good optimization tool which can optimize single file or a whole project and track module dependencies, but when you start to pair it up with .NET project you end up thinking about stuff that are not supported. For example RequireJS optimization tool can copy whole project to different directory and to optimize files there, but that is not regular workflow for .NET project. In .NET world to publish project you typically use built-in publish workflow rather then manually copying files.

I’ve seen other approaches also, where you use optimizer tool to optimize only Scripts directory to another release directory and then to hack project file to include those files in project, but that solution is kinda messy in my opinion.

Approach that worked for my use case is to use ASP.NET optimization features to create optimized bundles and then to configure RequireJS to look for modules in those bundles. It turned out to be fast solution, although not very elegant since there is double configuration.

## Bundling part ##

define your bundles in App_Start/BundleConfig.cs:

	bundles.Add(new ScriptBundle("~/bundles/test").Include(
                       "~/Scripts/jquery-{version}.js", 
                       "~/Scripts/q.js", 
                       "~/Scripts/globalize.js"));

This is test bundle that bundles three libraries.

## RequireJS configuration part ##

To configure RequireJS I will inject some script in _Layout view right after loading RequireJS library:

	<script src="~/Scripts/require.js"></script>
 
    @if (!HttpContext.Current.IsDebuggingEnabled)
    {
        <script>
            requirejs.config({
                bundles: {
                    '@Scripts.Url("~/bundles/test").ToString()': [
                        'jquery',
                        'globalize',
                        'q']
                }
            });
        </script>
    }

A few things to note here:

* We are not using data-main attribute for RequireJS configuration script, instead we are loading it manually after our new configuration.
* We are using RequireJS [“bundles” config parameter](http://requirejs.org/docs/api.html#config-bundles) to tell RequireJS where to search for modules. Configuration above simply states that modules jquery, globalize and q can be found in a bundle we created earlier. That way when RequireJS needs to load script it will load optimized version only if we are in release mode.
* With ‘@Scripts.Url(“~/bundles/test”).ToString()’ line we are obtaining optimized url for the bundle we created.

## Summing up ##

And that’s it! I said it would be simple but not very elegant. The only part I don’t like here is that there is double configuration of bundles, first in .NET code and latter in javascript for RequireJS configuration. But if you don’t mind that solution is pretty straightforward, we are still using all benefits of RequireJS but we are not using it’s optimization tool, instead we are telling it where it can find our optimized bundles.

Happy requiring :)