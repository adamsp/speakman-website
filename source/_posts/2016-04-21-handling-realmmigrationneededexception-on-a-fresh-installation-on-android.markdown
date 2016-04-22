---
layout: post
title: "Handling RealmMigrationNeededException on a fresh installation on Android"
date: 2016-04-21 18:33
comments: true
categories: android realm backup
---

Back in November, I had just started using [Realm](https://realm.io/) on Android and was having some troubles. I'd occasionally need to make a model change, and being early on in development I was happy to just delete the Realm and start again - in production you'd want to perform a migration so you don't lose any user data.

However, the "delete and re-install" approach wasn't working as expected - I kept getting a `RealmMigrationNeededException`:

```
io.realm.exceptions.RealmMigrationNeededException: RealmMigration must be provided
```

This doesn't make sense! I should be able to uninstall an app and upon reinstalling it I should have a fresh slate to work with. As it turns out, not quite. I couldn't figure out why at the time, but [the workaround](https://github.com/realm/realm-java/issues/1856) was to simply add a `deleteRealmMigrationIfNeeded()` call to my Realm configuration when building it. I made a note to deal with this before release, and carried on my way.

<!-- more -->

This morning I was getting ready to publish and Lint warned me that I didn't handle [Android 6.0 Marshmallow automatic backup](http://developer.android.com/intl/es/training/backup/autosyncapi.html). After some investigation, I realised that this was backing up and restoring my Realm files! The order of operations which caused the above issue was:

1. app backup occurs
2. uninstall app
3. install app (ie launching from Android Studio)
4. restore backup (note before the app launches!)
5. continue launching app

It seemed simple enough to handle - I'd just exclude the `default.realm` and `default.realm.lock` files from backup and it'd work. Unfortunately this still backs up the Realm log files, all preference files (plenty of third party libraries make use of shared prefs) and even files related to instant-run! This makes a "clean install" not quite what you'd expect - not clean at all.

My recommendation is to explicitly _include_ only the things you want. For example, I only care about my users settings - I can re-retrieve everything else remotely - so my `xml/backup.xml` looks like this:

``` xml
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>    
    <include domain="sharedpref" path="speakman.whatsshakingnz_preferences.xml"/>
</full-backup-content>
```

You also need to reference this file in your manifest:

``` xml
<manifest ... >
    <application ...
        android:fullBackupContent="@xml/backup">
        ...
</manifest>
```

Note that you [must specify the `.xml` extension](http://stackoverflow.com/q/36773020/1217087) when backing up shared preferences files - this is an implementation detail we unfortunately have to worry about, which is a bit strange, especially as we both specify a domain for the file and do _not_ specify the file extension in code.

If you're having trouble with this, I'd also recommend [reading through this StackOverflow question & answer](http://stackoverflow.com/q/33743941/1217087), as following through this helped a lot with figuring out what was going on.

Finally, the last useful bit of info I have is how to _wipe_ a backup. You *must have the app installed*, and then you can wipe the existing server-side backup with:

```
adb shell bmgr wipe com.google.android.gms/.backup.BackupTransportService com.yourpackage
```

Note that the `BackupTransportService` part refers to the default transport for backup - you should check what yours is by running `adb shell bmgr list transports` - the default will be marked with a `*`.

