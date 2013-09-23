---
layout: post
title: "Reflections on finishing an Android app"
date: 2013-02-28 22:31
comments: true
categories: android
---

A few days ago I finally finished the application I've been working on in my spare moments over the last month or two. It's called [Wookmark Viewer](https://github.com/adamsp/wookmark) and it's a simple little app that lets you browse the latest images saved on [Wookmark.com](http://www.wookmark.com) (Wookmark is an 'image bookmarking' site, so there's all sorts of images from all over the web that get saved there). This was an interesting project for me, as I got to use a few different open source libraries (including one I ended up almost totally rewriting), switched IDE from Eclipse to IntelliJ, and had to figure out some new Android features I hadn't used before.

This post-mortem picks apart what I enjoyed building, what caused me troubles, and what needs changing - the app is far from perfect.

<!-- more -->

### User Experience

The app should be fairly easy to pick up and use for anyone who's used an app with a sliding menu before. These include Facebook, NHL Game Center, YouTube and Falcon Pro, among others - so the sliding menu system is not an uncommon one. While I've tried to keep the user experience consistent, the final result is actually (in my opinion) quite bad, and completely inconsistent.

Swipe open the side-menu, and choose 'New' (assuming you're currently looking at 'Popular' images). Now, press the Back button on the device - and exit the app. The idea of swapping the fragments in/out via the menu, instead of navigating to a new page, may be lost on the user. Certainly I've exited the app by accident a few times when I just wanted to go to the previous page.

However, even this poor behaviour isn't consistent. If you go to the 'Color Search' page and search of a colour, you can hit the Back button and return to the search page from the results. I consider this to be good behaviour on its own, but it's still very confusing since it's so different to every other page.

Finally, the 'Settings' page is different again. Clicking on Settings brings forward an entirely new activity - with no access to the sliding menu, no branding (on 2.2/2.3), and no subheadings on the settings. On newer versions of Android you're provided with a `PreferenceFragment` which you can use like a regular `PreferenceActivity`, but as a fragment. Unfortunately this has not been implemented in the support library, and I couldn't find a quick/easy way of doing it, so (since I was keen to just get the damn thing finished) I went the easy way of just using a `PreferenceActivity` - resulting in this inconsistent behaviour.

### Open source libraries

Wookmark Viewer utilises a total of 5 open source libraries: [SlidingMenu](https://github.com/adamsp/SlidingMenu) for the menu system; [ActionBarSherlock](https://github.com/JakeWharton/ActionBarSherlock) for the action bar view styling; [LazyList](https://github.com/adamsp/LazyList) to lazy-load the images automatically in the background, off the UI thread; [ColorPickerPreference](https://github.com/attenzione/android-ColorPickerPreference) for the colour picker; and finally [AntipodalWall](https://github.com/adamsp/AntipodalWall) for the Pinterest-style view - more on this below.

Sliding Menu and ActionBar Sherlock worked well together - all I had to do was fork Sliding Menu and let the classes extend `SherlockFragment` and `SherlockActivity` instead. Easy. Open source is good for this - I was able to modify the code as necessary, on top of being able to step through the code when I wanted to know what was going on behind the scenes.

I made some modifications to the LazyList library as well. Originally it scaled all images it loaded; scaling is now optional for each image loaded, with the ability to set the scale factor when the `ImageLoader` class is instantiated. I also added the ability to supply a listener when you call `DisplayImage`, so that when the image is finished loading the calling class can update the UI - for example by removing a progress bar. I need to provide overloads for the `DisplayImage` method so that existing code can continue to use the class exactly as before, and then I'll send a pull request back to the original author.

I chose the 'AntipodalWall' library as my base Pinterest-style view to work with as it allowed a varying number of columns, worked on Android 2.2 and up, and was easy to set up - none of the other options met all those criteria. Unfortunately, the app quickly ran out of memory - there was no view recycling. This is fine for a static, finite number of resources, but the nature of the app means that there are an infinite number of images to load. I spent some time working on rewriting this to implement view recycling - it's now an `AdapterView`, recycling views as they scroll off screen and supplying them back to the `getView` method of the `Adapter`. In addition I've overridden the `onSaveInstanceState` and `onRestoreInstanceState` methods so the scroll position and visible views are kept when the device is rotated or the app is paused.

There are a few problems with my implementation of this, however. It could be simplified a little, as I'm not sure my class and variable names will make too much sense to others, though I did work on refactoring that a little recently. It doesn't handle views resizing (for example if content like an image loads in the background and a view needs resizing) - in fact, it requires views to come pre-measured from the `Adapter` and then scales them to fit, which only really works for my use case of knowing the size beforehand, and probably doesn't work for views that contain more than just a single image. And it doesn't behave as expected with respect to some methods; the `setNumberOfColumns` methods for example cannot be called at any time, it has to be called _before_ you call `setAdapter`, which has the potential for confusion.

Once I've fixed these issues, I'm a little confused as to what I should be doing about sending a pull request or not. A diff between the original and my code reveals that while a lot of the original code remains, the file is mostly new content. Certainly, anyone who was using the old library would not be able to use my version without a significant refactor - they'd have to implement `Adapter`, for a start. So I don't know if I should leave my fork as it is - a fork - or send a pull request, or create a new repository with a new name as a new project altogether. When I'm happy with it, I'll probably send an email to the creator of the original project and get his opinion; I'm more than happy to send the PR if he wants it!

### What's the point?

Well, for an actual use-case for the app, as the API stands right now there isn't much of one, really. The mobile site works well, looks a lot better, and offers much greater functionality. But it does have some limitations - it only offers a single-column view for images, for example.

Mostly, writing this app was simply good experience. I got some experience with some new libraries, and a new API - which is great, as reading other peoples code is an excellent way to grow as a developer. I learned a lot about the Android application life cycle (which I'd effectively managed to ignore with my other Android app), and figured out how to recycle views efficiently.

### Why isn't it on the Play Store?

Currently, there's no way to filter adult/NSFW content. While these are tagged on the website, that information is unfortunately not available in the data returned from the API. I've been in contact with the creator of the Wookmark website recently, and asked if it's possible to add this information - if so, I can filter all NSFW content, and obey the 'No nudity' rule of the Play Store [developer content policy](https://play.google.com/about/developer-content-policy.html).

Until then, if you want to load the app onto your device manually, you can either build it from source or I can send you an APK file - just send me a message on [Twitter](https://twitter.com/adamsnz).

### Other thoughts

Unfortunately, Color Search doesn't work that well. Indexing images by colour is, I understand, fairly difficult. It works for values such as 0xFF0000 (red), or 0x000000 (black) - but not for 0xFA0000 (slightly less saturated red). A little experimentation shows the search works for colour values 0xXXYYZZ - that is, where the R/G/B values are chosen from the set of numbers 00, 11, 22, …, DD, EE, FF, rather than the full range 00-FF. I can probably hack this fairly easily to find a "closest" colour to the one that comes out of the colour picker - this is a better solution than the current case of not finding any results at all, in most cases.

Partway through development of this app I switched from Eclipse to IntelliJ - I wish I'd done it sooner. IntelliJ worked immediately with my already installed Android SDK, and after figuring out a few nuances I've found it to be a significantly easier IDE to use, and much more stable. One problem I've recently noticed though is that Eclipse used tab indentation, and IntelliJ uses 4 spaces, so my indentation on any class I've edited in IntelliJ is now a mixture of both. Oops.

That's all the thoughts I have for now. It's unfortunate I can't keep this app up on the Play Store, as I did spend some time on it, but that's the way of things, I guess. If I can get a little extra info out of the API then it'll only take a few minutes to update and publish. In the meantime, I've sure learned a lot!