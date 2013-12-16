---
layout: post
title: "Broken JSONObject creation from a UTF-8 input String"
date: 2013-12-17 06:04
comments: true
categories: 
---

> 12-16 12:01:40.446: W/System.err(3873): org.json.JSONException: Value ﻿  of type java.lang.String cannot be converted to JSONObject

Faced this issue, again, at work today. We have a build system with build variants for different customers. To add a new customer, we just create a new folder, add the images and add a JSON config file to suit the new customers settings. We read from that file and into a JSON string (and then into a JSON object) something like this:

```
InputStream inStream = context.getResources().openRawResource(R.raw.local_config);
String json = IOUtils.toString(inStream);
JSONObject jsonObject = new JSONObject(json);
```

Sometimes, new customers speak a language other than English, and we have to save non-ASCII characters. In this case, the file gets saved as UTF-8. Testing this isn't a problem on my devices (Galaxy S2/Nexus 7) - but my tester has twice come back to me now and said that it doesn't work on our 2.3 device.

<!-- more -->

Figuring out the problem this time was pretty quick - I plugged her test phone in, saw this error popping up in Logcat and it triggered my memory about what was wrong. The problem is that the value hidden in that error message (encoded in this case as `0xEF 0xBB 0xBF`, often showing up as ï»¿ - see the [Wikipedia page](http://en.wikipedia.org/wiki/Byte_order_mark#Representations_of_byte_order_marks_by_encoding)) is a Byte Order Mark. This is used to signal the [endianess](http://en.wikipedia.org/wiki/Endianness) of the text stream. However, in UTF-8 it probably shouldn't even be there (but is still technically legitimate):

{% blockquote Wikipedia http://en.wikipedia.org/wiki/Byte_order_mark#UTF-8 %}
The Unicode Standard permits the BOM in UTF-8, but does not require nor recommend its use. Byte order has no meaning in UTF-8, so its only use in UTF-8 is to signal at the start that the text stream is encoded in UTF-8.
{% endblockquote %}

Because of this, Java doesn't actually support automatically reading the BOM as an indicator of encoding - it adds it as part of the string, so you have to strip it out.  If you don't, automatic parsers such as the one built into JSONObject may freak out and give you a confusing error like the one above. Reading the message, it _appears_ that it can't convert a String, which doesn't make sense, as the constructor takes a String. It's actually referring to the invisible (or in some cases barely visible) BOM character between the words "Value" and "of".

So why is it working correctly on my devices? [This bug](https://code.google.com/p/android/issues/detail?id=18508) logged in 2011 was 'fixed' by updating the built in JSON reader to handle UTF-8 strings with or without the Byte Order Mark. This change came in with Ice Cream Sandwich (Android 4.0) - hence why my tester is seeing the problem and I am not.

The fix in our case has been to simply fix the file - the BOM shouldn't be there anyway, so we just remove it. You can do this in Notepad++ by opening the UTF-8 file, clicking the Encoding menu and selecting "Encode in UTF-8 without BOM". This may show up as "ANSI as UTF-8" in the encoding field at the bottom-right.

The other, more general option (if you can't control the source of the JSON you're trying to parse) is to always 'clean' your incoming JSON string. This workaround was suggested in the original bug:

```
public Reader inputStreamToReader(InputStream in) throws IOException {
    in.mark(3);
    int byte1 = in.read();
    int byte2 = in.read();
    if (byte1 == 0xFF && byte2 == 0xFE) {
      return new InputStreamReader(in, "UTF-16LE");
    } else if (byte1 == 0xFF && byte2 == 0xFF) {
      return new InputStreamReader(in, "UTF-16BE");
    } else {
      int byte3 = in.read();
      if (byte1 == 0xEF && byte2 == 0xBB && byte3 == 0xBF) {
        return new InputStreamReader(in, "UTF-8");
      } else {
        in.reset();
        return new InputStreamReader(in);
      }
    }
}
```

There are also [many](http://stackoverflow.com/questions/1835430/byte-order-mark-screws-up-file-reading-in-java), [many](http://commons.apache.org/proper/commons-io/apidocs/org/apache/commons/io/input/BOMInputStream.html) other solutions available.

Wonderful. Note that if you know your file is encoded a certain way, you should _always_ pass the encoding to the reader - never depend on the default charset to be what you need. It's worth spending some time reading about [Unicode](http://en.wikipedia.org/wiki/Unicode) and the various encodings you're likely to encounter - [Windows-1252 (or CP-1252)](http://en.wikipedia.org/wiki/Windows-1252), [UTF-8](http://en.wikipedia.org/wiki/UTF-8) and [UTF-16](http://en.wikipedia.org/wiki/UTF-16), and how to interpret the bytes for these encodings. I find [fileformat.info](http://www.fileformat.info/info/unicode/char/FEFF/index.htm) to be extremely useful, as well as the [HexEditor Notepad++ plugin](http://sourceforge.net/projects/npp-plugins/files/Hex%20Editor/) for looking directly at the bytes (which is reportedly a bit unstable with the latest version of NP++, though I've never had any issues) - there will no doubt be something similar either built in to or available for your text editor of choice.

Text encoding problems are painful to deal with - and if you're not sure what you should be using, [use UTF-8](http://www.utf8everywhere.org/).