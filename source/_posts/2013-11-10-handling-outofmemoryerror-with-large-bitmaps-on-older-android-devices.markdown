---
layout: post
title: "Handling OutOfMemoryError with large bitmaps on older Android devices"
date: 2013-11-10 12:42
comments: true
categories: android 20-things-20-weeks
---

If you've ever worked with bitmaps on an Android device before, you've [likely](http://stackoverflow.com/questions/477572/strange-out-of-memory-issue-while-loading-an-image-to-a-bitmap-object) [encountered](http://stackoverflow.com/questions/14235287/suggestions-to-avoid-bitmap-out-of-memory-error?lq=1) the [dreaded](https://code.google.com/p/android/issues/detail?id=8488) `OutOfMemoryError` 'bitmap size exceeds VM budget'. This issue can present itself immediately when testing, however on older devices it may not manifest except in certain cases. The reason for this is as follows:

{% blockquote Android Developer Documentation http://developer.android.com/training/displaying-bitmaps/cache-bitmap.html %}
In addition, prior to Android 3.0 (API Level 11), the backing data of a bitmap was stored in native memory which is not released in a predictable manner, potentially causing an application to briefly exceed its memory limits and crash.
{% endblockquote %}

Depending on what you're doing, there is a way to get around this.

<!-- more -->

The situation where I encountered this was at work when working on a control for displaying a seat map for a movie theatre as part of a ticket purchasing wizard. It shows the screen, the seats, some seat numbers, etc. From there the app user is able to pick seats to sit in for watching the movie. Previously this had been built by drawing many `Button` controls with a custom drawable. This was terribly inefficient, as all those controls had to be totally redrawn whenever the user tried to zoom, and was practically unusable for large theatres (with hundreds of seats) even on top end devices.

Clearly this was due for a rewrite. The method I worked out for doing this was to create a 'base' bitmap from the theatre data showing all empty and already-sold seats. I'd use this as a static base image, and then paint 'selected' seats on top of that as the user taps to select/deselect seats they'd like to sit in.

This method had a few benefits we didn't enjoy with the old method:

- we only had to create the whole theatre model (calculating seat positions etc) once, when creating the base image (previously it was re-calculating seat sizes and locations at every zoom level, ugh)
- since it was an image, we could now just drop it inside a [TouchImageView](https://github.com/MikeOrtiz/TouchImageView) and that would handle zooming and panning (and [this pull request](https://github.com/MikeOrtiz/TouchImageView/pull/33) maps touch inputs back to our original image co-ordinates after zoom)
- the static base image meant we only had to perform N+1 passes across the canvas when drawing seat selections, where N was the number of selected seats (typically low, so this is very fast)

So off I went and coded this brilliant design. The code for the `SeatingImageView` control ended up looking _something_ like this:

``` java
public class SeatingImageView extends TouchImageView {

    private Bitmap mImmutableBase;

    public void setBaseImage(Bitmap baseImage) {
        if (baseImage.isMutable())
            baseImage = Bitmap.createBitmap(baseImage); // Immutable copy
        mImmutableBase = baseImage;
        setImageBitmap(mImmutableBaseBitmap.copy(Bitmap.Config.ARGB_8888, true));
    }

    public void drawSeats(List<Drawable> seats) {
        if (mImmutableBase == null) return;

        Bitmap mutable = immutablebase.copy(Bitmap.Config.ARGB_8888, true);
        Canvas canvas = new Canvas(mutable);
        for(Drawable seat : seats) {
            seat.draw(canvas);
        }

        setImageBitmap(mutable);
    }
}
```

So you'd set your base image, then overlay some selected seat images on top of that as necessary. I tested this on my phone (Galaxy SII i9100, Android 4.1) and my Nexus 7 (2012 model, Android 4.3) and sent it off to QA to be approved.

But our tester sent it back. She said it was crashing whenever she selected a seat - but only on certain cinemas. This was odd, as I couldn't replicate it at all. I went and had a chat to her, and sure enough, it was definitely crashing on her device (an old HTC running Android 2.3). I borrowed the phone and went about figuring this out.

Of course, it was the dreaded `OutOfMemoryError`. But how to fix this? I was already capping the size of the bitmap when building the base image and scaling seats down to fit. If I forced the max size to be lower, then large cinemas started to look awfully pixelated when zoomed in. I did some logging of the memory, and it appeared that the OOM was occurring at the time we created the new image with the seats - `Bitmap mutable = immutablebase.copy(Bitmap.Config.ARGB_8888, true);`.

We had in memory at this point 3 copies of the bitmap:

1. the immutable base image that wasn't being displayed (`mImmutableBase`)
2. the _copy_ of the immutable base we'd created that was currently being displayed to the user (`setImageBitmap(mImmutableBaseBitmap.copy(Bitmap.Config.RGB_8888, true));`)
3. the copy we'd _just created_ to draw the newly selected seats onto (`Bitmap mutable = immutablebase.copy(Bitmap.Config.RGB_8888, true);`)

That seemed easy enough to handle - we'd just get rid of the one being displayed before we created a copy of the immutable base, then we'd only ever have 2 in memory at once. I updated my `drawSeats` method to look like this:

``` java
    public void drawSeats(List<Drawable> seats) {
        if (mImmutableBase == null) return;
        
        setImageBitmap(null); // Clear all references to the existing bitmap

        Bitmap mutable = immutablebase.copy(Bitmap.Config.ARGB_8888, true);
        Canvas canvas = new Canvas(mutable);
        for(Drawable seat : seats) {
            seat.draw(canvas);
        }

        setImageBitmap(mutable);
    }
```

But this didn't work either!

Reading through [this thread](https://code.google.com/p/android/issues/detail?id=8488#c80) (post #80 down is especially useful) helps to shed some light on what's causing us to run out of memory here. The bitmap has memory in both the native and Dalvik heap, and it's not getting recycled from native quickly enough. Luckily, there is a way to force this to occur.

The fix was to:

1. acquire a reference to the bitmap that is currently being shown - `getDrawable()`
2. tell the `ImageView` to show nothing - `setImageBitmap(null)` - while still holding a reference to the old bitmap
3. manually call `recycle()` on the old bitmap - this clears the native heap allocation
4. although we _shouldn't have to_ call `System.gc()`, I found that this was still required to consistently remove the bitmap from memory

``` java
public class SeatingImageView extends TouchImageView {

    private Bitmap mImmutableBase;

    public void setBaseImage(Bitmap baseImage) {
        if (baseImage.isMutable())
            baseImage = Bitmap.createBitmap(baseImage); // Immutable copy
        mImmutableBase = baseImage;
        setImageBitmap(mImmutableBaseBitmap.copy(Bitmap.Config.ARGB_8888, true));
    }

    public void drawSeats(List<Drawable> seats) {
        if (mImmutableBase == null) return;
        recycleOldImage();

        Bitmap mutable = immutablebase.copy(Bitmap.Config.ARGB_8888, true);
        Canvas canvas = new Canvas(mutable);
        for(Drawable seat : seats) {
            seat.draw(canvas);
        }

        setImageBitmap(mutable);
    }

    private void recycleOldImage() {
        Drawable oldImage = getDrawable();
        if (oldImage != null) {
            setImageBitmap(null);
            BitmapDrawable oldBitmap = (BitmapDrawable)oldImage;
            oldBitmap.getBitmap().recycle();
            System.gc();
        }
    }
}
```

This fixed the bug! The memory logging I’d put in showed that were were only keeping at max two copies of the base image in memory at a time, and more importantly we weren’t seeing any crashes.

However, the logs were also showing that we were still precariously close to the memory limit for the device. I was concerned about other devices with [even lower memory limits](http://stackoverflow.com/questions/4351678/two-questions-about-max-heap-sizes-and-available-memory-in-android) - or other edge case theatre layouts we didn’t have examples for. This required something of a minor design change to resolve.

I'd been depending on using ARGB_8888 config for the alpha channel, providing a transparent background behind the seat images to match the background for the rest of the screen. After some experimentation I discovered that there was no noticable change in the colour of my seat images when switching to RGB_565, but the memory usage dropped by a large amount - enough that I was happy I wasn't going to hit the cap again. It was simple enough to modify the control to take a 'background' colour at creation, which reproduced the effects of transparency. Of course if you're faced with the same situation but are using a background with a gradient, or a colour not accurately reproducable in RGB_565, this will not work for you as easily.

Other tips:

- use RGB_565 if you can - it uses a lot less memory than ARGB_8888 (2 bytes per pixel instead of 4)
- if you're debugging memory issues with bitmaps, __use an Android 3.0 or higher device__ to debug, since bitmap memory allocations are reflected correctly in the Dalvik heap on these devices (see the [memory docs](http://developer.android.com/training/articles/memory.html#Bitmaps))
- always test on the lowest spec device you have available to you, even if you're not doing all your development on that