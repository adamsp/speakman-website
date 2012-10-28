---
layout: post
title: "Google Maps zoom levels on Android"
date: 2012-10-28 12:40
comments: true
categories: android
---

I had an interesting problem today where I needed to scale the default zoom for the map view for my [Android app](https://play.google.com/store/apps/details?id=speakman.whatsshakingnz), depending on the screen size. I'd previously hardcoded it to a zoom level of 6. This worked nicely on my testing device (a Nexus One) and looked OK (but not great) on a Galaxy S3 - but I saw it last night on a Nexus 7 and it looked ridiculous. My desire was to have the map view show the whole of New Zealand, filling up as much of the screen as possible. On the Nexus 7, the country was tiny.

<!-- more -->

I'd previously considered the fact that I would likely need to adjust the zoom level on a per-device level, and had added a method stub with the intent of adding some logic in there. Up til now I hadn't bothered with it, as, well, "It works on my device!" However looking at it on this Nexus 7, I figured it was time to do something about it.

A bit of Googling around showed that the problem of zooming relative to screen size was common - but the [common problem/solution](http://stackoverflow.com/questions/2666922/auto-size-zoom-on-google-maps-in-java-depending-android-screen-resolution) was to ensure the map zoomed to span a set of markers in an `ItemizedOverlay`. I specifically **did not** want to do this - I want to show the whole country, not just the areas where the earthquakes are! 

The `MapController.zoomToSpan(int latSpanE6, int lonSpanE6)` method looked like it would do what I wanted, but honestly, it's fucked. It gave me either zoom level 5 or zoom level 7, and I could never get it to give me zoom 6 (which is what I wanted, for the screen size on the emulator I was trying it on). Incrementally decreasing the size of the area I was requesting it to zoom to was no help. Admittedly the <a href="https://developers.google.com/maps/documentation/android/reference/com/google/android/maps/MapController#zoomToSpan(int, int)">documentation</a> gives no guarantees, and says that after the zoom "at least one of the new latitude or the new longitude will be within a factor of 2 from the corresponding parameter." This wasn't good enough.

I ended up doing it the hard way and experimenting with different screen resolution emulators until I found the right zooms. I figured 5, 6 and 7 would probably do it, depending on screen size. My code now looks like this:

``` Java getDefaultZoomForDevice() https://github.com/adamsp/wsnz-android/blob/master/Whats%20Shaking%20NZ/src/speakman/whatsshakingnz/fragments/MapFragment.java#L117 Source
private int getDefaultZoomForDevice() {
	WindowManager wm = (WindowManager) getActivity().getApplicationContext().getSystemService(Context.WINDOW_SERVICE);
	Display display = wm.getDefaultDisplay();
	int width = display.getWidth();

	if(width < 480)
		return 5;
	else if (width < 720)
		return 6;
	else
		return 7;
}
```
	
I went with these resolutions because they represent some of the most common sizes among popular phones. Below 480px wide we have 320x480 devices such as the LG P500 (Optimus One) or the Galaxy Ace. Below 720px wide we have the common 480x800 devices such as my Nexus One, or the Galaxy S and Galaxy S II. And finally we have even larger devices with higher resolutions, such as the 720x1280 Galaxy S III (this is the most common device for all downloads of What's Shaking, NZ? for Android) and HTC One X, and the 800x1280 Nexus 7 tablet.

There are some obvious problems with this solution. It's not generic at all, and works only for New Zealand. The `Display.getWidth()` call is actually deprecated since API Level 13, however I want to support older devices as well - currently nearly 45% of all my downloads for this app are Android 2.3 and below. Also, note that this solution doesn't work very well for people with strange resolution phones - anything that doesn't fall into the broad categories I've defined above is likely to meet with a strange/unfortunate default zoom. However if your screen size is that weird, there's probably not a whole lot more I can do about it - the Android Maps API doesn't allow anything more granular than these discrete levels, and these zoom levels fit New Zealand to the screen the best for the given sizes. Lastly, it won't scale properly when even larger devices are released.

However, despite these problems, I still found it to be the simplest, and most effective way of handling zoom at a per-device level. I would love to see a more granular zoom level (in Windows Phone you supply a double for zoom level), as it would presumably fix the problems with the `zoomToSpan` failures (this is a far more generic solution and would almost certainly be preferable). However, even if that does come about it won't make much difference. With all these older devices still in use that won't support it, it'll take a long time to make enough of a dent in the user base that it's worth thinking about again.

[{% img bottom /images/android-maps/android_maps_large.PNG 160 240 Large screen, 720x1280px, zoom level 7 %}](/images/android-maps/android_maps_large.PNG)
[{% img bottom /images/android-maps/android_maps_medium.PNG 160 240 Medium screen, 480x800px, zoom level 6 %}](/images/android-maps/android_maps_medium.PNG)
[{% img bottom /images/android-maps/android_maps_small.PNG 160 240 Small screen, 320x480px, zoom level 5 %}](/images/android-maps/android_maps_small.PNG)

