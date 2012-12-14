---
layout: post
title: "Converting WP7 Maps to WP8"
date: 2012-12-08 11:07
comments: true
categories: 
---

After [converting](http://msdn.microsoft.com/en-us/library/windowsphone/develop/jj207030.aspx) a Windows Phone 7 application ([What's Shaking, NZ?](http://www.whatsshaking.co.nz)) to Windows Phone 8, I noticed a few deprecation warnings around the Maps SDK. Converting the code to use the WP8 Maps SDK instead was fairly straightforward, but there were a few gotchas which I've covered in this post.

<!--more-->
_Note: This post assumes you've already converted your Windows Phone 7 app to Windows Phone 8 and are wondering how to get rid of the deprecation messages._

_It covers converting your code to use the new Pushpins (assuming you were using the default ones previously - though a glance over the Windows Phone 7 custom Pushpin image docs indicates to me that it should be fairly straightforward to port those over as well, after a read through this), as well as the changes required in XAML._

_This post does not delve into displaying routes or providing directions, etc._

{% img bottom /images/wp7-maps-to-wp8-maps/maps_deprecated.PNG Deprecation Warnings %}

### Deleting old references

First, delete both the old [Windows Phone Toolkit](http://phone.codeplex.com/) if you were using it (I was using it for the `ToggleSwitch` control), and the `Microsoft.Controls.Phone.Maps` library from your project references. If some of your other code breaks (ie, the ToggleSwitch), don't worry, we're going to fix that later.

There will of course be references to these namespaces throughout your code. Feel free to delete these now, or as we go.

While you're changing things in the Solution Explorer, you may as well update the WMAppManifest file - you need to include the new `IP_CAP_MAP` capability.

{% img bottom /images/wp7-maps-to-wp8-maps/maps_app_manifest.PNG WMAppManifest %}

### Changes to XAML

Next, edit your XAML to reference the new xmlns declaration:

```
xmlns:maps="clr-namespace:Microsoft.Phone.Maps.Controls;assembly=Microsoft.Phone.Maps"
```

Now your `<maps />` tag will probably show up with some blue squiggly underlines, previously I had this on one of my Map pages:

``` xml Old XAML
<maps:Map Grid.Row="1" Name="QuakeMap"     CredentialsProvider="your_maps_api_key_here"     ZoomLevel="5.3"     ZoomBarVisibility="Collapsed"    CopyrightVisibility="Collapsed"     LogoVisibility="Collapsed"     ScaleVisibility="Visible">    <maps:Map.Center>        <my:GeoCoordinate Altitude="NaN" 
            Course="NaN" 
            HorizontalAccuracy="NaN" 
            Latitude="-41" 
            Longitude="173" 
            Speed="NaN" 
            VerticalAccuracy="NaN" />    </maps:Map.Center></maps:Map>
```

However, my new XAML looks like this:

``` xml New XAML
<maps:Map Grid.Row="1" Name="QuakeMap"           ZoomLevel="5.3"          Center="-41, 173"          Loaded="QuakeMap_Loaded"></maps:Map>
```

Much simpler, and all the previous properties I had marked as `Collapsed` are now collapsed by default (and no longer accessible).

### Pushpins

Unfortunately the other part of the Maps that we're talking about today (the Pushpins) has become _more_ complicated, not less. Where previously you would simply create a `Pushpin` object, assign it a location and some content (and perhaps an event listener), and then add it via a `Map.Children.Add(pin)` call, now it's not that simple.

To add the Pushpins, we now need to download and reference the _new_ WPToolkit via NuGet. Go on, I'll wait (the new one I used was published Oct 30 2012, was top result after searching for WPtoolkit). We need this for the Pushpins, as they are no longer included in the built-in Maps library (which is now located in the `Microsoft.Phone.Maps` assembly, as seen above). This should also fix any other issues you had where things from the previous Toolkit were no longer available (once you update your `using` statements).

Once that's done, you can start fixing your existing Pushpin code. First, add a reference to the package you just downloaded:

```
using Microsoft.Phone.Maps.Toolkit;
```

The next thing you'll notice is that the `Location` property of the Pushpin no longer exists. It's now called `GeoCoordinate`, that's all. That should be all you need to change there:

``` c# Pushpin code
Pushpin pin = new Pushpin{    GeoCoordinate = quake.Location,    Content = quake.FormattedMagnitude};
```

Now to add the pin, we need to:

1. Create a `MapOverlay` object and add the pin to the overlay
2. Create a `MapLayer` object and add the overlay to the layer
3. Add the `MapLayer` to the `Layers` property of the map

So let's do that:

```
MapOverlay overlay = new MapOverlay();overlay.Content = pin;overlay.GeoCoordinate = quake.Location;overlay.PositionOrigin = new Point(0, 1);
MapLayer layer = new MapLayer();layer.Add(overlay);
QuakeMap.Layers.Add(layer);
```

A few things to note here:

* Setting the `MapOverlay.PositionOrigin` is the point in your overlays content you would like centered on the `GeoCoordinate`. The overlay has (0,0) as top left, and (1,1) as bottom right of your content. Since we're using the old Pushpin image, we want (0,1) for bottom left. If (for example) you had an arrow pointing from left-to-right and you wanted the tip of the arrow to be pointing at the location, you would specify `overlay.PositionOrigin = new Point(1, 0.5);` for the center of the right-hand side.
* A Map can have multiple `MapLayer`s
* A `MapLayer` can have multiple `MapOverlay`s
* We have to specify the `GeoCoordinate` property twice - once for the `Pushpin` itself, and once for the `MapOverlay` it's going into.

If you're adding multiple pins simultaneously, you may want to add them in separate layers or on the same layer. I've opted for inserting all pins on the same layer, as I've found this exhibits the same behaviour I was experiencing previously - pins added later appear on top - so I've found no reason to experiment.

For further reading, check out the <a href="http://msdn.microsoft.com/en-us/library/windowsphone/develop/jj207045(v=vs.105).aspx">Windows Phone Dev Center</a>.

### Maps API Key

You may have noticed earlier that you no longer specify the `CredentialsProvider` in the XAML. Instead we have an event handler for the `Loaded` event on the map. As <a href="http://msdn.microsoft.com/en-us/library/windowsphone/develop/jj207033(v=vs.105).aspx#BKMK_appidandtoken">detailed on MSDN</a> we now specify an ApplicationID and AuthenticationToken in code. This looks to be very simple, though I haven't tried it yet (as you get the ApplicationID and AuthenticationToken during the app submission process).

``` c# Map.Loaded Event Handler
private void QuakeMap_Loaded(object sender, RoutedEventArgs e){    Microsoft.Phone.Maps.MapsSettings.ApplicationContext.ApplicationId = "ApplicationID";    Microsoft.Phone.Maps.MapsSettings.ApplicationContext.AuthenticationToken = "AuthenticationToken";}
```
