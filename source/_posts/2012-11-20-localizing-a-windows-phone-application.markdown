---
layout: post
title: "Localizing a Windows Phone (7) application"
date: 2012-11-20 08:49
comments: false
categories: windows-phone
---

I've been trying to clean up the What's Shaking, NZ? for Windows Phone 7 [codebase](https://github.com/adamsp/wsnz-windowsphone) recently, as there was quite a bit of duplicated code and plenty of room for problems (read: shitty code). I'll be migrating it to Windows Phone 8 soon, and want it as clean as possible before I start (note here that I haven't .

<!-- more -->

One part of the clean up was localization. Localization of your resources is important, as it allows you to easily distribute your application in multiple languages without having to modify your code. Too few developers do this, and having an application display its content in the language of the device is a great way to make your users feel appreciated. I've done localization in Java previously, but never in .NET. I did some Googling and found a few guides, it was pretty simple:

* Add an `AppResources.resx` file (for your default language, as specified in Assembly Info for the project)
* Add some strings with keys
* Reference the keys in code wherever the strings are needed
* Additional languages are just `AppResources.xx-YY.resx`, where `xx` is the region and `YY` is the language. For example, `AppResources.de-DE.resx`. You can see the full list <a href="http://msdn.microsoft.com/en-us/library/hh202918(v=vs.92).aspx">here</a>.
* Finally edit the `*.csproj` file to include your newly supported languages.

Pretty simple. However, the <a href="http://msdn.microsoft.com/en-us/library/ff637520(v=vs.92).aspx">guide</a> I was following didn't detail how to handle the case where you had multiple projects. Oh dear. I couldn't find anything online about supporting multiple projects - other than just having a new `AppResources.resx` file per project, which I didn't want.

As it turns out, it's still very simple to do. Instead of adding the `AppResources.resx` file to the current project, just add a new project as a Windows Phone class library and then add the `AppResources.resx` file to that. Now, you can reference it from anywhere, provided you include a reference and a `using` statement from the other project back into the resources project:

``` c# MainPage.xaml.cs https://github.com/adamsp/wsnz-windowsphone/blob/dev/WhatsShakingNZ/MainPage.xaml.cs#L43 Source

using WhatsShakingNZ.Localization;
...
private void InitializeApplicationBar()
{
    ApplicationBarIconButton refreshButton = new ApplicationBarIconButton();
    refreshButton.Text = AppResources.AppBarRefreshButtonText;
    ...
}
```

To access the resources from XAML, you need to add the following class to your resources library:

``` c# LocalizedStrings.cs https://github.com/adamsp/wsnz-windowsphone/blob/dev/Localization/LocalizedStrings.cs Source
public class LocalizedStrings
{
    public LocalizedStrings()
    {
    }

    private static AppResources localizedResources = new AppResources();

    public AppResources LocalizedResources { get { return localizedResources; } }
}
```

You will also need to add the following to the `App.xaml` file (the guide I linked to above doesn't detail all of this):

``` xml App.xaml
<Application 
...
xmlns:local="clr-namespace:WhatsShakingNZ.Localization;assembly=WhatsShakingNZ.Localization" />

    <Application.Resources>
        <local:LocalizedStrings x:Key="LocalizedStrings" />
        ...
    <Application.Resources>
...
</Application>
```

And then to reference the resources in the XAML for each page, change anything that was using hardcoded text to use a binding as follows: 

``` xml
<TextBlock x:Name="PageTitle" 
    Text="{Binding Path=LocalizedResources.PageTitleLatestQuakes, Source={StaticResource LocalizedStrings}}" 
    Margin="9,-7,0,0" 
    Style="{StaticResource PhoneTextTitle1Style}"/>
```

You can see all of these changes in [this commit](https://github.com/adamsp/wsnz-windowsphone/commit/49c511f9be2181955b3a5e7b06bf88068ec32ec4).

There are a few important gotchas with this:

* The DLL filename **cannot end in "Resources"**. I had some trouble with this, but I eventually found [this blog post](http://isolatedstorage.wordpress.com/2010/10/25/reserved-xap-file-names-resource-dll/) detailing the fact there are some reserved file names in XAP files. Specifically, you can't have DLLs ending in 'Resources'. If you have named your project as "Resources", everything will compile fine but your app will crash when it runs. It's easy enough to fix - I renamed my project (and the properties that named the DLL) from `WhatsShakingNZ.Resources` to `WhatsShakingNZ.Localization`. After doing this, everything worked perfectly.
* You must specify the `AppResources.resx` Access Modifier as `public` or you won't be able to access the resource properties:
{% img bottom /images/wp7-localization/access_modifier.PNG %}
* The default language as specified in the Assembly Information under the project Properties window is the one that your default `AppResources.resx` file is considered to be. If the device your application is running on is running any language other than your default, it will search for the resource string in the corresponding language resource file. If that resource file does not exist (or, if the specific key it is looking for does not exist in that region-specific file), then it will fall back to your default. This means you can have some strings localised and some not, even within the same page.
* To support additional languages, you have to add the `AppResources.xx-YY.resx` file, and also declare in the `.csproj` file for the **main project** that it supports the language (not the project containing your resource files). You have to edit this file manually in a text editor, as detailed in step 4 of <a href="http://msdn.microsoft.com/en-us/library/ff637520(v=vs.92).aspx">the guide linked above</a>. You can check out [this MSDN blog](http://blogs.msdn.com/b/webdev/archive/2008/06/10/localizing-a-silverlight-application.aspx), <a href="http://msdn.microsoft.com/en-us/library/dd941932(VS.95).aspx">this guide</a> or [this forum post](http://social.msdn.microsoft.com/Forums/en-US/vsx/thread/7e3267e4-ab1f-4fd0-90f4-d9292831bb2b/) for a bit more information on how and why.