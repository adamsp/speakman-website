---
layout: post
title: "Getting started with Volley for Android"
date: 2013-11-25 17:55
comments: true
categories: 20-things-20-weeks android volley
---

[Volley](https://android.googlesource.com/platform/frameworks/volley) is a new Android networking library from Google (well, by ‘new’ I mean from [May, at I/O 2013](https://developers.google.com/events/io/sessions/325304728) - so some 7 months ago). It has some cool features - request queueing with priorities, automatic selection of the best HTTP library [depending on Android version](https://android.googlesource.com/platform/frameworks/volley/+/master/src/com/android/volley/toolbox/Volley.java), and a nifty view for [automatically loading images](https://android.googlesource.com/platform/frameworks/volley/+/master/src/com/android/volley/toolbox/NetworkImageView.java). Unfortunately, even 7 months on, there’s pretty minimal documentation available. However across StackOverflow, a bunch of blogs and the source code, there’s plenty to go on to figure out how to do some basic tasks.

<!-- more --> 

## Getting the library

I’ll assume you have [git](http://git-scm.com/) and [ant](http://ant.apache.org/) installed.

First, we have to get the library:

```
git clone https://android.googlesource.com/platform/frameworks/volley
```

Now we have the source code, we need to build it:

```
cd volley
ant jar
```

Now, we have `volley.jar` in the `bin` directory. Copy this into `libs` in Eclipse (via drag & drop through the GUI so it sets everything up properly) or set it up in your `build.gradle` if you’re using Studio. Wonderful.

## Some basic setup

Volley works by sending requests to a `RequestQueue`. To create one of these requests, you override the `Request` object and implement a few methods:

``` java
queue.add(new Request<String>(Method.GET, url, errorListener) {

	@Override
	protected Response<String> parseNetworkResponse(NetworkResponse response) {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	protected void deliverResponse(String response) {
		// TODO Auto-generated method stub
		
	}});
```
 
You can send these with a priority (by overriding `getPriority()`), so that higher priority requests get sent to the front of the queue, not the back. Useful if, for example, you’re loading some images in the background, but the user clicks on something that needs immediate download.

Before we can use a queue, we have to set one up. This should done as a singleton. Since the easiest way of creating a `RequestQueue` requires a `Context`, you can either subclass `Application` (which the official docs advise against) or do it this way:

``` java VolleyProvider.java
public VolleyProvider {
    private static RequestQueue queue = null;
    
    private VolleyProvider() { }

    public static synchronized RequestQueue getQueue(Context ctx) {
        if (queue == null) {
            queue = Volley.newRequestQueue(ctx.getApplicationContext());
        }
        return queue;
    }
}
```

And usage:

``` java
RequestQueue queue = VolleyProvider.getQueue(mContext);
```

There are a few other ways of constructing a queue, allowing you to specify your own HTTP stack, cache, thread pool size, etc.

## Now let’s GET some JSON

So now we've got our default queue set up, we can send a request. As you saw earlier, a request requires you to implement two methods - `parseNetworkResponse` and `deliverResponse`. The first of these methods parses your network response into some object that you're expecting, __from a worker thread__. The second delivers that response back to your UI thread, __unless `parseNetworkResponse` returns `null`__.

To fetch some simple JSON back from a given URL, there's a convenient utility class that comes packaged in `com.android.volley.toolbox` called `JsonRequest`.

This class manages parsing any request body string into a byte array (the `getBody` method returns a `byte[]`), as well as specifying the content type headers, etc. You still have to implement the `parseNetworkResponse` abstract method from before, though you now supply a listener for the success case instead of an override. So now our request looks a bit like this (using [Gson](https://code.google.com/p/google-gson/) for parsing the response, because it's awesome):

``` java
public class Person {
	long id;
	String firstName;
	String lastName;
	String address;
}

...

String url = "http://person.com/person?id=1234";
Request request = new JsonRequest<Person>(Method.GET, url, null, new Listener<Person>() {

	@Override
	public void onResponse(Person response) {
		// Do something with our person object 
	}
}, new Response.ErrorListener() {

	@Override
	public void onErrorResponse(VolleyError error) {
		// Handle the error 
		// error.networkResponse.statusCode
		// error.networkResponse.data
	}
}) {

	@Override
	protected Response<Person> parseNetworkResponse(NetworkResponse response) {
		String jsonString = new String(response.data, HttpHeaderParser.parseCharset(response.headers));
		Person person = new GsonBuilder().create().fromJson(jsonString, Person.class);
		Response<Person> result = Response.success(person, HttpHeaderParser.parseCacheHeaders(response));
		return result;
	}
};
queue.add(request);
```

## And POST some back to the server

POSTing JSON back is equally as easy! Instead of passing in null for our body, we pass in a JSON String.

``` java
String url = "http://person.com/person/update?id=1234";
String body = new GsonBuilder().create().toJson(somePerson);
Request request = new JsonRequest<Person>(Method.POST, url, body, new Listener<Person>() {

	@Override
	public void onResponse(Person response) {
		// Do something with our person object 
	}
}, new Response.ErrorListener() {

	@Override
	public void onErrorResponse(VolleyError error) {
		// Handle the error 
		// error.networkResponse.statusCode
		// error.networkResponse.data
	}
}) {

	@Override
	protected Response<Person> parseNetworkResponse(NetworkResponse response) {
		String jsonString = new String(response.data, HttpHeaderParser.parseCharset(response.headers));
		Person person = new GsonBuilder().create().fromJson(jsonString, Person.class);
		Response<Person> result = Response.success(person, HttpHeaderParser.parseCacheHeaders(response));
		return result;
	}
};
```

## Is there an easier way?

Sort-of. I've abstracted the JSON parsing out so you only have to handle the success and the failure cases. If you've got more complex objects that need custom type adapters, you could put the Gson object creation and type adapter registration into another class somewhere and call it from here. Just drop this `GsonRequest` class in and you can use it by simply passing in the class of object you expect, as follows.

``` java GsonRequest.java https://gist.github.com/adamsp/7637132
/**
 * Copyright 2013 Adam Speakman
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package your.package.here;

import java.io.UnsupportedEncodingException;

import com.android.volley.NetworkResponse;
import com.android.volley.ParseError;
import com.android.volley.Response;
import com.android.volley.Response.ErrorListener;
import com.android.volley.Response.Listener;
import com.android.volley.toolbox.HttpHeaderParser;
import com.android.volley.toolbox.JsonRequest;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonSyntaxException;

public class GsonRequest<T> extends JsonRequest<T> {

    Class<T> mResponseClass;

    public GsonRequest(int method, String url, String requestBody, Class<T> responseClass, Listener<T> listener,
            ErrorListener errorListener) {
        super(method, url, requestBody, listener, errorListener);
        mResponseClass = responseClass;
        // Do some generic stuff in here - for example, set your retry policy to
        // longer if you know all your requests are going to take > 2.5 seconds
        // etc etc...
    }

    @Override
    protected Response<T> parseNetworkResponse(NetworkResponse networkResponse) {
        try {
            String jsonString = new String(networkResponse.data, HttpHeaderParser.parseCharset(networkResponse.headers));
            T response = new GsonBuilder().create().fromJson(jsonString, mResponseClass);
            com.android.volley.Response<T> result = com.android.volley.Response.success(response,
                    HttpHeaderParser.parseCacheHeaders(networkResponse));
            return result;
        } catch (UnsupportedEncodingException e) {
            return com.android.volley.Response.error(new ParseError(e));
        } catch (JsonSyntaxException e) {
            return com.android.volley.Response.error(new ParseError(e));
        }
    }

}

```

And usage:

``` java
Request request = new GsonRequest<T>(Method.POST, url, body, Person.class, new Listener<Person>() {

	@Override
	public void onResponse(Person response) {
		// Do something with our person object 
	}
}, new Response.ErrorListener() {

	@Override
	public void onErrorResponse(VolleyError error) {
		// Handle the error 
		// error.networkResponse.statusCode
		// error.networkResponse.data
	}
});
```

## What about that easy image loading?

Loading images with Volley is one of my favourite features of the library. Once it's setup, it's really easy to use. It handles loading images off the UI thread, can show a default image and an error one, and handles caching all for you. You need to set up an `ImageLoader`, similar to how you set up the `RequestQueue` as a singleton:

``` java ImageLoaderProvider.java
public ImageLoaderProvider {
    private static ImageLoader imageLoader = null;
    
    private ImageLoaderProvider() { }

    public static synchronized ImageLoader getImageLoader(Context ctx, RequestQueue queue) {
        if (imageLoader == null) {
            imageLoader = new ImageLoader(queue, new LruBitmapCache(getCacheSize(ctx)));
        }
        return imageLoader;
    }
	
	/**
	 * Returns a cache size equal to approximately three screens worth of images.
	 */
	private int getCacheSize(Context ctx) {
        final DisplayMetrics displayMetrics = ctx.getResources().getDisplayMetrics();
        final int screenWidth = displayMetrics.widthPixels;
        final int screenHeight = displayMetrics.heightPixels;
        final int screenBytes = screenWidth * screenHeight * 4; // 4 bytes per pixel

        return screenBytes * 3;
    }
}
```

Now, replace your `ImageView` objects with `NetworkImageView` ones:

``` xml
    <com.android.volley.toolbox.NetworkImageView
        android:id="@+id/some_image"
        ... />
```

And finally, all you need to do is pass your `NetworkImageView` the URL of the image you'd like loaded, and the `ImageLoader`:

``` java
ImageLoader imageLoader = ImageLoaderProvider.getImageLoader(mContext, VolleyProvider.getQueue(mContext));
((NetworkImageView)findViewById(R.id.some_image)).setImageUrl(imgUrl, imageLoader);
```

There are also methods available such as `setDefaultImageResId` and `setErrorImageResId`, for supplying default and error resources.

## Anything else?

Volley has a default TTL on requests of 2.5 seconds - after this, it'll retry the request. This can result in some unexpected behaviour - for example where your error listener gets called (immediately after the retry), then your success listener gets called a little while later (when the original request returns). You can fix this by specifying a timeout in your request:

``` java
public static final int REQUEST_TIMEOUT_MS = 10000;
...
request.setRetryPolicy(new DefaultRetryPolicy(REQUEST_TIMEOUT_MS, DefaultRetryPolicy.DEFAULT_MAX_RETRIES, DefaultRetryPolicy.DEFAULT_BACKOFF_MULT));
```

Another thing to be aware of is that the image loading will cache images in the full size they come down as. This means if you’re downloading images at full resolution but only displaying them at a much smaller one, you’re going to be caching them at full res. If this is in a list view, you’re going to be pushing stuff out of the cache (and then re-downloading them) a lot more often than desirable.

You can get around this by changing some code in [`NetworkImageView`](https://android.googlesource.com/platform/frameworks/volley/+/master/src/com/android/volley/toolbox/NetworkImageView.java). The important bit is near the end of the `loadImageIfNecessary(final boolean isInLayoutPass)` method. The code makes a call to the following method in the `ImageLoader` class:

``` java ImageLoader.java https://android.googlesource.com/platform/frameworks/volley/+/master/src/com/android/volley/toolbox/ImageLoader.java
public ImageContainer get(String requestUrl, final ImageListener listener) {
    return get(requestUrl, listener, 0, 0);
}
```

Notice how that calls an overload that takes some `int` values?


``` java ImageLoader.java https://android.googlesource.com/platform/frameworks/volley/+/master/src/com/android/volley/toolbox/ImageLoader.java
public ImageContainer get(String requestUrl, ImageListener imageListener,
            int maxWidth, int maxHeight) {
    ...
}
```

Well, if we ‘fix’ the code back in `NetworkImageView` to pass in the width & height of the view, then the image gets scaled down and cached at the smaller size (this takes is utilised in the `doParse` method of [`ImageRequest`](https://android.googlesource.com/platform/frameworks/volley/+/master/src/com/android/volley/toolbox/ImageRequest.java):

``` java NetworkImageLoader.java
ImageContainer newContainer = mImageLoader.get(mUrl,
    new ImageListener() {
        ...
    },
    getMeasuredWidth(),
    getMeasuredHeight());
```

Note that if you pass the image URL in for use in a different place, **it’ll use the (scaled down) image from the cache** - so if you need the full resolution image, this solution will need some modification.

## Wow, Volley can do lots of stuff!

And I certainly haven't covered all of it here. There's loads more that it can do. I'd recommend looking through some of the classes in `com.android.volley.toolbox` to see what else is already written for you, and for some ideas of how to use some of the other cool features it has to offer.


