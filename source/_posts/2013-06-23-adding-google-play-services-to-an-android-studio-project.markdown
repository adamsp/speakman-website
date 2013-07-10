---
layout: post
title: "Adding Google Play Services to an Android Studio project"
date: 2013-06-23 10:55
comments: true
categories: 
---

Adding a support library to Android Studio is a bit different to how it's done in Eclipse. Where you'd add a 'project' in Eclipse, in Studio you add a 'Module' (which is a sub-project of your overall application - similar to Projects in a Solution, if you've done any .NET development). In this post I detail how to add the Google Play Services project, but you should be able to follow the instructions to add any support library.

<!-- more -->

__Edit July 10 2013:__ Note that this post only applies to projects __not__ using Gradle.

Most of this information can be found on the [Android Developer site](https://developer.android.com/google/play-services/setup.html).

This guide assumes you already have an application project set up, and you're looking to add this support library in to enable new features. For setting up the main project, check out the [Android Studio documentation](http://developer.android.com/sdk/installing/studio.html).

1. Update Google Play Game Services via the SDK Manager - you can launch this from _Tools -> Android -> SDK Manager_. This will download all the required files to your Android SDK install directory.
2. Copy the `google-play-services_lib/` folder (__the whole folder__, not just the .jar) from  `<android-sdk>/extras/google/google_play_services/libproject/google-play-services_lib/` to your `lib/` folder in your project.
3. In Android Studio, select _File -> Import Module_, then select the `google-play-services_lib` folder (the one you just copied into your project directory, not the one from your SDK directory).
4. Make sure 'Create module from existing sources' is selected, then Next, Next, until you reach the end of the wizard.
5. Now you have to add a reference to your new module from your existing application. Right click your existing game module (should be the top line in the Project explorer) and select _Open Module Settings_. Along the left side select _Modules_ and you should see both your existing application module and your newly added library module listed. Make sure your app is selected, then choose the _Dependencies_ tab. There should be a __+__ sign at the bottom (on a Mac), or on the right side (on Windows). Click this then select _Module dependency_ and add the _google-play-services_lib_ module.
6. Ok, now you have everything set up correctly in your existing app module, but you need to finish setting up the one you just imported. Still in the settings window from the previous step, select the _google-play-services_lib_ module under the _Modules_ section. Again, click the __+__ on the Dependencies tab but this time we're going to choose 'Jars or directories'. Navigate to the `google-play-services_lib/libs/` folder (again, the one in your application directory and not the SDK directory) and pick _google-play-services.jar_.
7. Finally, we have to make sure that other modules have access to the google-play-services.jar. In the _Dependencies_ tab for the _google-play-services_lib_ module, check the 'Export' checkbox for the _google-play-services.jar_ entry. This makes the JAR accessible to any other module that references this one.

The important part is that you import the whole project, not just the JAR file. If you only import the JAR, you don't get the associated resources. Check out this [Google Developers](http://www.youtube.com/watch?v=nkJS_W-VC9I) video for more detail - it's the first mistake they list.

If you use proguard, add this to your proguard-project.txt:

    -keep class * extends java.util.ListResourceBundle {
        protected Object[][] getContents();
    }

You can confirm that it's worked by building the project (you may need to do a _Build -> Rebuild Project_) and making sure there's no errors. To see the imported module in the Project explorer, switch the drop down at the top of the Project explorer to 'Packages' instead of 'Project'.

If you're adding a project other than Google Play Services, such as [ActionBarSherlock](http://actionbarsherlock.com/), that project may use the Android support library. If you're using this too (as is likely) you need to ensure you only have one support library JAR referenced. You should export the JAR from the library (as in step 7 above) and then delete the one in your own module.