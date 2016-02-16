---
title: "Creating Fiddler extension for custom filtering"
layout: "post"
date: 2014-03-13
summary: "In this post I will explain how easy it is to create fiddler extension for custom filtering."
summaryImage: "/images/posts/fiddler-extension.png"
tags: [c#, programming, fiddler]
---

've been using Fiddler for a long time and every time I start exploring certain feature I'm positively surprised how well designed product it is. What you can't do through its UI you can program in Fiddler Script, or for more complex features you can create fiddler extension.
In this article I will walk you through a process of writing Fiddler Extension from scratch. I will create new tab page with custom icon, create UI for extension and hookup to requests and responses to perform some filtering and manipulation.

I also plan to use this extension as a base for writing future extensions because I think it covers most tasks extension developers need to do: create UI for configuration, persist configuration and use configuration inside separate interface.

If you haven't used fiddler before, it's a debugging/analyzing software which installs as a proxy server enabling you to monitor all traffic between your local application and remote server. If you are a web developer it's simply a must have tool.

## Overview ##

I have split up extension in three parts: UI, configuration and filtering.

For UI part idea is to hook up to event when fiddler UI is completely loaded and then to add a new TabPage in which I will instantiate user control for extension UI.

Configuration part is responsible for configuration persistence, providing default configuration, and keeping instance of currently active configuration.

Filtering part is code that runs on every request/response and performs some meaningful work based on configuration we have set up in the UI.

This is what final extension looks like:

<img class="img-responsive" src="/images/posts/fiddler-extension.png" />

This extension will provide functionality to create filter presets. For every preset you can set host filter and url filter. This functionality is a bit different then Fiddler's Host filter because it enables use of wildcards for IP addresses, here you can simply specify 192.* to include all hosts within that address range. URL filter is same as host filter (enables wildcards) but its scope is full URL.

There is also functionality to send custom CORS headers with every response and in that way enable you to overcome same origin policy while in development. It supports setting following CORS headers: Access-Control-Allow-Origin, Access-Control-Allow-Headers and Access-Control-Allow-Credentials. With this functionality I can easily develop Phonegap applications in Google Chrome and it won't complain about same origin policy.

## Project configuration ##

There is good documentation how to setup new extension project at Fiddler website so I'm not going to repeat it. Go through it and don't forget to set up post-build event so it can copy extension to correct location automatically after successful build.

## Fiddler interfaces ##

In this extension I will implement two fiddler extension interfaces: IFiddlerExtension and IAutoTemper2. First interface allows me to hook up to onLoad event which fires when Fiddler UI finishes loading, and latter allows me to hook up to request and do some work.

Interface implementation cannot be any simpler, create class that implement extension interface and Fiddler will automatically load it at correct time provided that you have copied extension DLL at correct location (see Project Configuration).

## UI part ##

To create new tab in Fiddler UI you need to implement IFiddlerExtension and OnLoad method. Here I'm creating new TabPage, adding new icon (from embedded resources) to correct image list and setting TabPage's ImageIndex to last icon in list. And to finish UI initialization I'm adding ConfigForm UserControl to tab page.

```csharp
	public class Extension : IFiddlerExtension
    {
        public void OnBeforeUnload()
        {
            ConfigurationManager.SaveConfig();
        }
 
        public void OnLoad()
        {
            var oPage = new TabPage("iBanking");
 
            using (var stream = GetType().Assembly.GetManifestResourceStream("iBankingFiddlerExtension.icon.png"))
            {
                if (stream != null)
                {
                    FiddlerApplication.UI.imglSessionIcons.Images.Add(Image.FromStream(stream));
                    oPage.ImageIndex = Enum.GetNames(typeof (SessionIcons)).Length;
                }
            }
 
            var oView = new ConfigForm { Dock = DockStyle.Fill };
 
            oPage.Controls.Add(oView);
 
            FiddlerApplication.UI.tabsViews.TabPages.Add(oPage);
        }
    }
```
	
ConfigForm UserControl is implemented with WindowsForms technology. Basic idea is to bind UI controls to configuration object so any change to UI should reflect to active configuration and vice versa.

## Configuration part ##

To handle configuration part I've created new class - ConfigurationManager. It's responsibility is to persist configuration, to provide default configuration, and to provide singleton access to configuration at every time. I'm using isolated storage (per user) for configuration file and XML serializer. Idea is to automatically load config on Fiddler startup and to save it when Fiddler is closing. I've implemented ConfigurationManager as static class with singleton property ActiveConfig which loads configuration from disk on first access. To save config when Fiddler is closing I used OnBeforeUnload event in IFiddlerExtension interface.

Relevant snippets:

```csharp
	public static Config LoadConfig()
	{
		using (
			var storage = IsolatedStorageFile.GetStore(IsolatedStorageScope.User | IsolatedStorageScope.Assembly,
				null, null))
		{
			if (!storage.FileExists(ConfigFile))
			{
				var cfg = GetDefaultConfig();
	 
				SaveConfig(cfg);
				return cfg;
			}
	 
			using (var stream = new IsolatedStorageFileStream(ConfigFile, FileMode.Open, storage))
			{
				var serializer = new XmlSerializer(typeof(Config));
	 
				return (Config) serializer.Deserialize(stream);
			}
		}
	}
	 
	protected static void SaveConfig(Config cfg)
	{
		using (
			var storage = IsolatedStorageFile.GetStore(IsolatedStorageScope.User | IsolatedStorageScope.Assembly,
				null, null))
		{
			using (var stream = new IsolatedStorageFileStream(ConfigFile, FileMode.Create, storage))
			{
				var serializer = new XmlSerializer(typeof(Config));
	 
				serializer.Serialize(stream, cfg);
			}
		}
	}
```

## Filtering part ##

In this part I'm implementing IAutoTamper2 interface to hookup to Fiddler's request and response events. I'm also using Configuration class I created before.

For filtering functionality idea is to convert wildcard syntax to regular expression, test coresponding headers and hide sessions that don't match filter. Filters are expected to be separated with comma. Example: *google.com, 192*, *test*.

Relevant snippets:

```csharp
	public void OnPeekAtResponseHeaders(Session oSession)
	{
		if (Config.SendCORSHeaders)
		{
			oSession.oResponse.headers["Access-Control-Allow-Origin"] =
				Config.CORSHost == "[auto]"
				? oSession.oRequest.headers["origin"] : Config.CORSHost;
	 
			oSession.oResponse.headers["Access-Control-Allow-Headers"] =
				Config.CORSHeaders;
	 
			if (Config.CORSAllowCredentials)
				oSession.oResponse.headers["Access-Control-Allow-Credentials"] = "true";
		}
	}
	 
	public void AutoTamperRequestBefore(Session oSession)
	{
		var preset = Config.ActivePreset;
		if (preset == null) return;
	 
		if (preset.EnableCustomHostFilter && !string.IsNullOrEmpty(preset.CustomHostFilter))
		{
			if (!Regex.IsMatch(oSession.host, WildcardToRegex(preset.CustomHostFilter)))
			{
				oSession["ui-hide"] = "true";
			}
		}
	 
		if (preset.EnableCustomUrlFilter && !string.IsNullOrEmpty(preset.CustomUrlFilter))
		{
			if (!Regex.IsMatch(oSession.fullUrl.ToLower(), WildcardToRegex(preset.CustomUrlFilter)))
			{
				oSession["ui-hide"] = "true";
			}
		}
	}
	 
	private string WildcardToRegex(string input)
	{
			var pattern = Regex.Replace(input, "\\s*,\\s*", ",");
	 
			pattern = "^(" + Regex.Escape(pattern).
				   Replace(@"\*", ".*").
				   Replace(@"\?", ".").
				   Replace(@",", "|") + ")$";
	 
		return pattern;
	}
```
	
## Debugging tips ##

o debug your extension you need to attach debugger to active Fiddler process. In Visual studio go to Debug -> Attach to process, find "Fiddler.exe" process and attach. After this step you can set breakpoints and debug. This technique is good for debugging interaction with extension, but if you have to debug extension initialization (before UI creation) you can add following code where you want breakpoint:

Debugger.Launch();
When you start Fiddler you will see dialog which prompts you to attach debugger, select correct extension solution and click Yes button.

<img class="img-responsive" src="/images/posts/attach-debugger.png" />

## Final thoughts ##

Creating this extension was really fun. Now I started to look at Fiddler with new eyes, I'm constantly thinking what I can do next to simplify HTTP traffic inspection and visualization for our projects.