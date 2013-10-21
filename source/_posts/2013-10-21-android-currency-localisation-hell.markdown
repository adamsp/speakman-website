---
layout: post
title: "Android Currency Localisation Hell"
date: 2013-10-21 17:45
comments: true
categories: android 20-things-20-weeks
---

We had a customer at work recently who had a special requirement around multiple currency support in our Android app. They have cinema sites in multiple countries, and they want customers to see the correct currency symbol when viewing sessions for a site. Up until now, the app has only ever had to deal with single currencies on a per-customer (and hence per-build) basis.

While implementing this multiple currency support, I came across something of a problem - the Android Currency code doesn't behave quite as you'd hope, and is inconsistent across versions. Sometimes you get a currency symbol where you're supposed to, sometimes you don't - and sometimes the symbol is a slightly different symbol in one locale to that which is in another (￥, I'm looking at you). I've now got a set of [test cases](https://github.com/adamsp/CurrencyFormattingDemo) which do a fair job of explaining the issue, as well as the solution we came up with which _mostly_ works.

<!-- more -->

### The status quo

Our app is designed to use a JSON configuration file to set customer-specific settings during build, including a single default currency symbol which we were prepending to the currency value. The items being purchased in the app all come down from a web service, and the values are specified in cents - every value gets divided by 100 to get the 'true' value for the currency. This is legacy behaviour in the service backend that has been in place for over a decade and cannot be changed.

Luckily however, we can _add_ to it. The design that came through initially was simply to allow the customer to specify a currency symbol on a per-site basis, and then expose this via the web service. Being developers, we didn't feel this was good enough. What about the case where the 'special case' sites (that is, the ones which don't match the default currency symbol) are in a different currency with the same symbol? (NZ$/AU$, or CA$/US$) Eventually we settled on specifying an [ISO 4217 currency code](http://en.wikipedia.org/wiki/ISO_4217) __per location that is a special case__ - 3 characters, and they're associated with a symbol. This is populated in a drop-down list in the existing configuration application for the site.

So, now we've got this currency code coming through for these special case sites. We should be able to format currency values using this, right? According to the [Currency documentation](http://developer.android.com/reference/java/util/Currency.html), we can. Our intent was to format the currency __value__ (whether numbers appear as 15,00 € like in France, or as $15.00 like in the US) using the device locale, while customising the currency __symbol__ - this would provide optimum readability for the user (the value appears in the format they're most used to) while also providing an accurate representation of what currency the figure is in.

So, after a bit of research I figured I should be able to write code like this:

``` java
public static String getFormattedCurrencyString(String isoCurrencyCode, double amount) {
	// This formats currency values as the user expects to read them (default locale).
	NumberFormat currencyFormat = NumberFormat.getCurrencyInstance();
	
	// This specifies the actual currency that the value is in, and provides the currency symbol.
	Currency currency = Currency.getInstance(isoCurrencyCode);
	
	// Note we don't supply a locale to this method - uses default locale to format the currency symbol.
	String symbol = currency.getSymbol();
	
	// We then tell our formatter to use this symbol.
	DecimalFormatSymbols decimalFormatSymbols = ((java.text.DecimalFormat) currencyFormat).getDecimalFormatSymbols();
	decimalFormatSymbols.setCurrencySymbol(symbol);
	((java.text.DecimalFormat) currencyFormat).setDecimalFormatSymbols(decimalFormatSymbols);
	
	return currencyFormat.format(amount);
}
```

Unfortunately, while I initially tested this with one or two samples and figured it would work as advertised, I was wrong.

### Certain locales cannot localise currencies

As I was writing unit tests for this, I discovered that I wasn't getting expected results. I was running these tests on a device (a Galaxy S II) set to New Zealand locale - and my tests were failing. When I ran them on an emulator (which defaults to US locale), I got _different_ results - some of the failing tests passed, but I got a new set of failures.

The failures on my device were cases where I was getting the ISO currency code back instead of the symbol. "AUD" instead of "AU$", etc. The case where I supplied "NZD" I was expecting "NZ$" - yet I was getting "$", and not "NZD" like the others. And even more confusing, these tests were passing on the emulator - I was getting the expected symbols!

So I tried supplying a `Locale` object and using that, rather than the device default, so I could see what behaviour I got on a variety of locales:

``` java
public static String getFormattedCurrencyStringForLocale(Locale locale, String isoCurrencyCode, double amount) {
	// This formats currency values as the user expects to read them (default locale).
	NumberFormat currencyFormat = NumberFormat.getCurrencyInstance(locale);
	
	// This specifies the actual currency that the value is in, and provides the currency symbol.
	Currency currency = Currency.getInstance(isoCurrencyCode);
	
	// Note we don't supply a locale to this method - uses default locale to format the currency symbol.
	String symbol = currency.getSymbol(locale);
	
	// We then tell our formatter to use this symbol.
	DecimalFormatSymbols decimalFormatSymbols = ((java.text.DecimalFormat) currencyFormat).getDecimalFormatSymbols();
	decimalFormatSymbols.setCurrencySymbol(symbol);
	((java.text.DecimalFormat) currencyFormat).setDecimalFormatSymbols(decimalFormatSymbols);
	
	return currencyFormat.format(amount);
}
```

Looking at the code above, the line `String symbol = currency.getSymbol()` is the one that fetches the symbol. The `getSymbol()` method has an overload `getSymbol(Locale locale)`. If I took the step of passing this method the `locale` parameter, I got different results. Interesting!

The [documentation](http://developer.android.com/reference/java/util/Currency.html) for `public String getSymbol (Locale locale)` in the `Currency` class says:

{% blockquote %}
Added in API level 1
Returns the localized currency symbol for this currency in locale. That is, given "USD" and Locale.US, you'd get "$", but given "USD" and a non-US locale, you'd get "US$".

If the locale only specifies a language rather than a language and a country (such as Locale.JAPANESE or {new Locale("en", "")} rather than Locale.JAPAN or {new Locale("en", "US")}), the ISO 4217 currency code is returned.

If there is no locale-specific currency symbol, the ISO 4217 currency code is returned.
{% endblockquote %}

The important part there is the last bit. **If there is no locale-specific currency symbol, the ISO 4217 currency code is returned.** That's what I was seeing - if the locale didn't 'know' how to format a currency symbol for the supplied currency, it would just return the currency code.

Huh, okay. How do we fix that, then?

As it turns out, the US locale has formatting for _most_ currency codes. It doesn't quite match in some cases (it might provide UK£ instead of £UK, for example) and in certain scenarios it doesn't have a symbol, but for the most part, it's better than anything else. There's one case where we don't want this to use the US locale though - USD ISO code, with a non-US device locale. We can fix that with a hard coded symbol of 'US$'.

There is also the issue that when the currency code matches the users locale (for example, NZD and en_NZ locale), the users see NZ$ rather than $. We handle this internally by utilising our existing behaviour of having a default currency symbol specified in the app build. If we receive a response that contains a currency code, we utilise the code for getting a currency symbol for that code. If we don't receive a currency code (which is the case most of the time, to maintain backwards compatibility, and the majority of cinemas don't actually support multiple countries), we just use the symbol from the build config. That code isn't shown here, but it's a simple check to see if the `isoCurrencyCode` value is null or empty, and if it is then we use the default symbol.

So, the final version of the method is as follows. Note that we still use the device locale for formatting the numbers, and where the symbol goes within the string - we only use US locale for the symbol itself.

``` java
public static String getFormattedCurrencyString(String isoCurrencyCode, double amount) {
	// This formats currency values as the user expects to read them (default locale).
	NumberFormat currencyFormat = NumberFormat.getCurrencyInstance();
	
	// This specifies the actual currency that the value is in, and provides the currency symbol.
	Currency currency = Currency.getInstance(isoCurrencyCode);
	
	// Our fix is to use the US locale as default for the symbol, unless the currency is USD
	// and the locale is NOT the US, in which case we know it should be US$.
	String symbol;
	if (isoCurrencyCode.equalsIgnoreCase("usd") && !Locale.getDefault().equals(Locale.US)) {
		symbol = "US$";
	} else {
		symbol = currency.getSymbol(Locale.US); // US locale has the best symbol formatting table.
	}
	
	// We then tell our formatter to use this symbol.
	DecimalFormatSymbols decimalFormatSymbols = ((java.text.DecimalFormat) currencyFormat).getDecimalFormatSymbols();
	decimalFormatSymbols.setCurrencySymbol(symbol);
	((java.text.DecimalFormat) currencyFormat).setDecimalFormatSymbols(decimalFormatSymbols);
	
	return currencyFormat.format(amount);
}
```

### But wait, there's more

Now, that seems pretty good, right? Not quite - there's a few scenarios you need to be aware of. Formatting numbers for France, one expects something like "15,00 $NZ" - that's a comma instead of a period, a space after the numbers, followed by the symbol and then the country code. That's how the French locale (fr_FR) localises currency values. Unfortunately, since we're using the US locale (en_US) to format the symbol, we get "15,00 NZ$". This is still completely readable, however it's not __quite__ right. It's probably good enough, but still unfortunate.

Additionally, I was also getting differences in my JPY tests. First, my phone (running Android 4.1) was getting ￥15 - that was what I expected, the yen does not have more than one unit. However the emulator was getting ￥15.00 - two decimal places, where there should be 0! So, I fired up a few more emulators and did some more testing.

It turns out that for versions of Android 4.0.3 and down, the currency format (the `NumberFormat.getCurrencyInstance(locale);` formatter) does not work correctly for locales that have only single units in their currency. If you check out the [sample project](https://github.com/adamsp/CurrencyFormattingDemo) you can see that for the Japanese Yen and the Chilean Peso, both of which have only single units, earlier versions of Android will format these with decimal places, where as 4.1 and up does not.

But wait, there's still more. Different locales also return _different versions of the same symbol_. The US locale (en_US) returns a [full-width ￥](http://www.fileformat.info/info/unicode/char/ffe5/index.htm) symbol, where as the Japan locale (ja_JP) returns a [regular ￥](http://www.fileformat.info/info/unicode/char/a5/index.htm) symbol. Similarly, the French locale (fr_FR) will return a [non-breaking space](http://www.fileformat.info/info/unicode/char/a0/index.htm) between the digits and the symbol, where as the French Canadian locale (fr_CA) which formats numbers the same way ("15,00 $NZ", like above) uses a [regular space](http://www.fileformat.info/info/unicode/char/0020/index.htm). This makes writing tests a pain in the ass, but it shouldn't have much impact on actually displaying these things to the user - of course, you do have to be careful if you're doing string comparisons.

### Currency localisation sucks

So, all up, what should've taken me an hour or so took over 2 days, working out why things weren't behaving themselves. Even after all that time, I'm still not sure I've got it all figured out - I've rewritten this blog post about 5 times, and I can't reproduce some things I had noted down from when I was doing this at work. Hopefully, reading through this saves someone else some pain and gives them an explanation as to why their tests are failing - or worse, users are reporting strange behaviour around currencies.

Of course, if you're only targetting one market, this may not be a problem for you at all. But be prepared for the day you expand - this could definitely come back and bite you.

(As a side note, I realise that the test cases I've supplied are far from comprehensive - I especially lost my incentive to continue when I discovered they were behaving differently on different devices, at least until I'd discovered why that was the case.)
