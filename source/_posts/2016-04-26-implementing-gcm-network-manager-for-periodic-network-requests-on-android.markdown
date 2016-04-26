---
layout: post
title: "Implementing GCM Network Manager for periodic network requests on Android"
date: 2016-04-26 14:55
comments: true
categories: android network google-play wsnz
---

In the process of rebuilding [What's Shaking, NZ?](https://github.com/adamsp/wsnz-android), I needed to implement a periodic network request (literally polling an API). I wanted to use the new [Job Scheduler](https://developer.android.com/reference/android/app/job/JobScheduler.html) API, but unfortunately, this is only available on API 21 and above. Luckily we can get similar functionality by using [GCM Network Manager](https://developers.google.com/cloud-messaging/network-manager), as [suggested on StackOverflow](http://stackoverflow.com/q/25203254/1217087). Note that the GCM Network Manager actually uses Job Scheduler behind the scenes in API 21+.

The [documentation](https://developers.google.com/cloud-messaging/network-manager) for this is somewhat hand-wavy. Here I attempt to provide a true step-by-step guide to implementing this. I assume you're _not_ already using GCM for something else in your app (as that was the case for me).

<!-- more -->

# Implement GcmTaskService

The first step is to import GCM in your `build.gradle`:

```
compile 'com.google.android.gms:play-services-gcm:8.4.0'
```

Now you can implement [`GcmTaskService`](https://developers.google.com/android/reference/com/google/android/gms/gcm/GcmTaskService). This is as simple as the following:

```
import com.google.android.gms.gcm.GcmNetworkManager;
import com.google.android.gms.gcm.GcmTaskService;
import com.google.android.gms.gcm.TaskParams;

public class SyncService extends GcmTaskService {
    @Override
    public int onRunTask(TaskParams taskParams) {
        // Perform your network request. Note you're already off the main thread here.
        return GcmNetworkManager.RESULT_SUCCESS;
    }
}
```

Great. So you get a callback, on a different thread, where you can do your stuff.

# Add the service to the manifest

The instructions say to add the service to the manifest and "Add all applicable intent filters. See details for intent filter support in the GcmTaskService API reference."

Note that the [GcmTaskService documentation](https://developers.google.com/android/reference/com/google/android/gms/gcm/GcmTaskService#constants) has `SERVICE_ACTION_EXECUTE_TASK` as the name for the `com.google.android.gms.gcm.ACTION_TASK_READY` intent filter. This is right now the only thing we need to care about.

We also need to add the `RECEIVE_BOOT_COMPLETED` permission so that our periodic sync will persist across reboots.

``` xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<application ... >
	<service
	    android:name=".SyncService"
	    android:exported="true"
	    android:permission="com.google.android.gms.permission.BIND_NETWORK_TASK_SERVICE">
	    <intent-filter>
	        <action android:name="com.google.android.gms.gcm.ACTION_TASK_READY" />
	    </intent-filter>
	</service>
</application>
```

# Schedule a persistent task

You construct a [`PeriodicTask`](https://developers.google.com/android/reference/com/google/android/gms/gcm/PeriodicTask) object using a [`Builder`](https://developers.google.com/android/reference/com/google/android/gms/gcm/PeriodicTask.Builder), and then pass that task to a `GcmNetworkManager` instance - and that's it! You can put this in your `SyncService` class and call `SyncService.scheduleSync(context)`:

``` java
public static void scheduleSync(Context ctx) {
    GcmNetworkManager gcmNetworkManager = GcmNetworkManager.getInstance(ctx);
    PeriodicTask periodicTask = new PeriodicTask.Builder()
            .setPeriod(SYNC_PERIOD_SECONDS) // occurs at *most* once this many seconds - note that you can't control when
            .setRequiredNetwork(PeriodicTask.NETWORK_STATE_CONNECTED) // various connectivity scenarios are available
            .setTag(PERIODIC_SYNC_TAG) // returned at execution time to your endpoint
            .setService(SyncService.class) // the GcmTaskServer you created earlier
            .setPersisted(true) // persists across reboots or not
            .setUpdateCurrent(true) // replace an existing task with a matching tag - defaults to false! 
            .build();
    gcmNetworkManager.schedule(periodicTask);
}
```

I've used the [Once](https://github.com/jonfinerty/Once) library to ensure that my periodic sync is scheduled once per app install (on first launch). I just call this method from my Application class `onCreate`.

``` java
private void scheduleSync() {
    if (!Once.beenDone(Once.THIS_APP_INSTALL, INIT_SYNC_ON_INSTALL)) {
        SyncService.scheduleSync(this);
        Once.markDone(INIT_SYNC_ON_INSTALL);
    }
}
```

# Re-schedule on app update

Finally, we need to ensure that our periodic task is re-scheduled after an app update by overriding the `onInitializeTasks` method.

> When your package is removed or updated, all of its network tasks are cleared by the GcmNetworkManager. You can override this method to reschedule them in the case of an updated package. This is not called when your application is first installed.
> 
> This is called on your application’s main thread.

This is trivial enough to do:

``` java
@Override
public void onInitializeTasks() {
    super.onInitializeTasks();
    // Re-schedule periodic task on app upgrade.
    SyncService.scheduleSync(this);
}
```

# Test it

You can test that your background process works by firing off the intent that triggers it:

``` bash
adb shell am broadcast -a "com.google.android.gms.gcm.ACTION_TRIGGER_TASK" \
    -e component speakman.whatsshakingnz/.network.SyncService \
    -e tag speakman.whatsshakingnz.network.SyncService.PERIODIC_SYNC
```

Note `speakman.whatsshakingnz` is the package, and `.network.SyncService` is the component name within that package. You need to specify the tag you used earlier, too. If you've got a debugger attached you can hit a breakpoint inside your `onRunTask` method and note that you're _not_ on the main thread.

# Gotchas

- you **have to reschedule on app update** - this is simple enough to do, make sure you remember to do it!
- check for Play Services! It's required for this to work.
- if the network is unavailable/doesn't meet the criteria you specified, you can't force the task to trigger via ADB (useful to remember if you keep your test device in airplane mode!)
- use the tags to filter out different events in the same service - `taskParams.getTag()` returns the tag that the task was created with.