---
layout: post
title: "Android Open Source licenses page"
date: 2013-09-24 20:49
comments: true
categories: android open-source
---

Ever used an open source library in your Android app? If you have, then you [probably](http://www.tldrlegal.com/browse) should have included a page with the license details for that library. If you did, great! You probably had the same question I did recently; how should you do that?

<!-- more -->

My first attempt looked like this - in fact, this is currently what my '[Wookmark Viewer](https://github.com/adamsp/wookmark)' licenses page looks like:

[{% img /images/android-licenses-page/wookmark_licenses.png 240 400 Wookmark Licenses %}](/images/android-licenses-page/wookmark_licenses.png)

However, while this page details the libraries used and their licenses, and provides links to those things, it isn't good enough. It says in the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html):

{% blockquote %}
You must give any other recipients of the Work or Derivative Works a copy of this License.
{% endblockquote %}

So how should I do that? Do I have to include the same license multiple times for different libraries that use the same license? How do I include that in a regular old TextView?

I revisited these issues at work recently when I was tasked with adding the licenses page to our app. After some time looking around online, I couldn't really find any suggestions as to how this page should behave, how it should look, or how to display licenses for multiple libraries. The only thing I found was [this Stack Overflow question](http://stackoverflow.com/questions/11300552/license-screen-about-phone-legal-information-open-licenses-screen), but that was enough of a lead to set me on the right path. I checked out some of the other Google apps - see the Play Music and Gmail apps licenses pages below. This is simply an HTML page displayed in a DialogFragment. This is more like it!

[{% img /images/android-licenses-page/play_music_licenses.png 240 400 Play Music Licenses %}](/images/android-licenses-page/play_music_licenses.png)
[{% img /images/android-licenses-page/gmail_licenses.png 240 400 Gmail Licenses %}](/images/android-licenses-page/gmail_licenses.png)


This answers the questions of how to display things nicely (including the full license text), how to handle multiple libraries with the same license, how to display any copyright notice, and how to link to any modified source code, as required in the [GPL-2.0](http://opensource.org/licenses/gpl-2.0.php) license, for example. It should also be simple enough to set up to automatically construct this page (or a similar one) in your build scripts - including any custom text you may want to add, as I've done above for my original attempt on the Wookmark app.

I've created a DialogFragment that reproduces the Google apps licenses page experience - [AndroidLicensesPage on Github](https://github.com/adamsp/AndroidLicensesPage).

If you want to use this fragment in your application, you need to include `LicensesFragment.java` in your projects source, as well as including the `licenses_fragment.xml` layout file in `/res/layout` and the `licenses.html` file in `/res/raw`. You should update the namespace to suit.

To display licenses for your app, you need to update the `licenses.html` file to suit (including any libraries you've used, their licenses, copyrights, and any links to source you may have modified, if required), then you can display it as you would any other [DialogFragment](http://developer.android.com/reference/android/app/DialogFragment.html):

```
// Create & show a licenses fragment just as you would any other DialogFragment.
FragmentTransaction ft = getSupportFragmentManager().beginTransaction();
Fragment prev = getSupportFragmentManager().findFragmentByTag("licensesDialogFragment");
if (prev != null) {
	ft.remove(prev);
}
ft.addToBackStack(null);

// Create and show the dialog.
DialogFragment newFragment = LicensesFragment.newInstance();
newFragment.show(ft, "licensesDialogFragment");
```

There are some TODOs in the LicensesFragment file - you should modify these things to suit your environment, though things will work fine without you needing to touch anything.

If you want to see an example of this in action, clone the repository and you should be able to open the included AndroidLicensesPageExampleProject in Android Studio. It should run directly on any device or emulator running Android 2.1 or higher.
