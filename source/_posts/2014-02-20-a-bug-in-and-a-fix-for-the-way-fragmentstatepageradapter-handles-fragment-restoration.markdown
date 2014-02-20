---
layout: post
title: "A bug in (and a fix for) the way FragmentStatePagerAdapter handles fragment restoration"
date: 2014-02-20 21:25
comments: true
categories: android open-source
---

Ever used a [`FragmentStatePagerAdapter`](https://developer.android.com/reference/android/support/v4/app/FragmentStatePagerAdapter.html)? We're using one at work for our ticket purchasing wizard. The user enters the wizard, and can progress to the next page once they've completed the current one. We control this by manipulating the stack of pages and notifying the adapter that the data has changed when a new page is available.

Unfortunately, when changing pages that have already been loaded, there's an unexpected bug. Specifically, when you load a page, remove it and then insert a new one in its place, the next time the fragment at that index is loaded, it receives the `savedInstanceState` bundle for the _old_ fragment.

<!-- more -->

# How'd you find _that_?

The specific use case where I discovered this was the case where a customer is purchasing tickets to a film, and they change their mind about which type of tickets they want.

First, the customer selects tickets that require manually selected seats. We save the tickets, receive the seating data, and send the customer to the next page where they can select from a seat in a map.

If the customer changes their mind at this stage and returns to the previous page, as soon as they make a change to their selected tickets we consider all future pages invalid. We 'remove' the seat selection fragment and notify the adapter. If the customer has now selected tickets that _don't_ require manual seat selection (that is, they've chosen tickets for an unallocated seating area), we save the tickets, receive empty seating data, and know to send them on to the "details" page where they can enter in their name and email.

This is where the process breaks down. Since the two fragments are different (one's called `SeatingFragment` and the other is `CustomerDetailsFragment`, say), I wasn't expecting to receive any saved instance state on the first load of the new fragment - however I was getting state passed in! This caused a crash, as I was depending on the state being null to assume first-load.

The state I was seeing was the state for the previously loaded fragment at that index. That is, when the `CustomerDetailsFragment` in the example scenario was loaded (replacing the `SeatingFragment`), it was receiving the saved state bundle for the `SeatingFragment`, when it should've been receiving no saved state bundle at all.

# Can you reproduce it?

I've written a [very simple example app](https://github.com/adamsp/FragmentStatePagerIssueExample) which shows this behaviour. If you swipe backwards and forwards you can see the fragments labeled "1", "2", "3", colored Red, Yellow and Green. Now, press the 'Switch Fragment' button. You'll be sent back to index 0 (fragment "1"). This forces the removal of fragment "3", which gets its state saved. But we've changed the content of the adapter - so next time you load fragment "3", you'll see that its color has changed to Blue. **This is a different fragment**, but it's label has been restored from the previous fragments saved state! If you rotate your device, or simply swipe back to the first view and then back to the third again, you'll see the correct label of "4" (it saves the state fresh when it removes it, resulting in the correct saved state next time it's loaded).

# Why does this occur?

If we take a look at the source code [as of this writing](https://android.googlesource.com/platform/frameworks/support/+/6d6186b9a2503200844febe1b8ba083206c7cbcd/v4/java/android/support/v4/app/FragmentStatePagerAdapter.java), we can see that the `FragmentStatePagerAdapter` stores a list of states:

```
private ArrayList<Fragment.SavedState> mSavedState = new ArrayList<Fragment.SavedState>();
```

Looking through the code we can see that this array is used in four places. It's used in `instantiateItem`, `destroyItem`, `saveState` and `restoreState`.	We can ignore `saveState` and `restoreState` for now, as they're just saving the adapters overall state into an external bundle, and then loading it back up.

First, let's take a look at what's going on in `destroyItem`. When a fragment is due to be destroyed, this method first starts a transaction (if one isn't already started), then pads out the `mSavedState` array with null entries until it's at least the size of the index of the fragment we're removing. 

```
    @Override
    public void destroyItem(ViewGroup container, int position, Object object) {
        Fragment fragment = (Fragment)object;

        if (mCurTransaction == null) {
            mCurTransaction = mFragmentManager.beginTransaction();
        }
        if (DEBUG) Log.v(TAG, "Removing item #" + position + ": f=" + object
                + " v=" + ((Fragment)object).getView());
        while (mSavedState.size() <= position) {
            mSavedState.add(null);
        }
```

Nothing too exciting there. It then saves the state of the fragment that is being removed into the corresponding index in the `mSavedState` list, and removes the fragment:

```
        mSavedState.set(position, mFragmentManager.saveFragmentInstanceState(fragment));
        mFragments.set(position, null);

        mCurTransaction.remove(fragment);
    }
```

Now let's see what happens in the other direction - instantiating an item. First thing to do is check and see if we already have a `Fragment` object created and stored at the given position. Short-circuit back out with this if we do:

```
    @Override
    public Object instantiateItem(ViewGroup container, int position) {
        // If we already have this item instantiated, there is nothing
        // to do.  This can happen when we are restoring the entire pager
        // from its saved state, where the fragment manager has already
        // taken care of restoring the fragments we previously had instantiated.
        if (mFragments.size() > position) {
            Fragment f = mFragments.get(position);
            if (f != null) {
                return f;
            }
        }
```

If however we _don't_ have a fragment there, we have to create one. This could be because we've never seen this page of the `ViewPager` before, or it could be because the page was removed due to the left/right limits (recall a `ViewPager` will only keep the first page to the left and right of the current one, by default).

```
        if (mCurTransaction == null) {
            mCurTransaction = mFragmentManager.beginTransaction();
        }

        Fragment fragment = getItem(position);
        if (DEBUG) Log.v(TAG, "Adding item #" + position + ": f=" + fragment);
```

Now, here's the important part. After we've asked our concrete subclass to create/instantiate a fragment for us (through the `getItem(position)` call), we check to see if we have any saved state *at that position*. There's the crucial part - we're **checking for saved state based on the fragments index in an array, rather than on some unique property of the fragment**.

```
        if (mSavedState.size() > position) {
            Fragment.SavedState fss = mSavedState.get(position);
            if (fss != null) {
                fragment.setInitialSavedState(fss);
            }
        }
```

The issue with this is that the fragment at that position may no longer be the same fragment as was there last time we displayed the page at this position! So that saved state bundle may no longer be the correct one.

Finally, we add the fragment to our list of fragments and display it:

```
        while (mFragments.size() <= position) {
            mFragments.add(null);
        }
        fragment.setMenuVisibility(false);
        fragment.setUserVisibleHint(false);
        mFragments.set(position, fragment);
        mCurTransaction.add(container.getId(), fragment);

        return fragment;
    }
```

# Fixes or workarounds?

Luckily, there's a way around this problem! Hurrah!

We simply need some way of identifying the fragments, and comparing whether this identifying value is the same or not when we try to restore state to a freshly instantiated fragment. The best way to do this is to ask our concrete subclass for an identifier for this fragment - a tag.

So, let's copy the [entire source of `FragmentStatePagerAdapter`](https://android.googlesource.com/platform/frameworks/support/+/master/v4/java/android/support/v4/app/FragmentStatePagerAdapter.java) and get started. First thing to do is add a way of getting tags from our subclasses. Since we don't want to break existing implementations that don't actually care about swapping out fragments, we won't make this method abstract. Instead it'll just `return null;` by default, and we treat that as the default case, reproducing existing behaviour.

```
    public String getTag(int position) {
        return null;
    }
```

Ok, so now we have a way of getting the tags, let's add an `ArrayList<String>` member variable to track our fragment tags:

```
    private ArrayList<String> mSavedFragmentTags = new ArrayList<String>();
```

Now we go through and handle this in all 4 places where `mSavedState` is touched.

In `instantiateItem` we must find the tag for the newly instantiated fragment first. Once we've got that, if we have saved state we can then compare this new tag with the saved tag. If they match, then we restore the state! If they don't, then we don't restore state. Easy.

```
        Fragment fragment = getItem(position);
        String fragmentTag = getTag(position);
        if (DEBUG) Log.v(TAG, "Adding item #" + position + ": f=" + fragment + " t=" + fragmentTag);
        if (mSavedState.size() > position) {
            String savedTag = mSavedFragmentTags.get(position);
            if (TextUtils.equals(fragmentTag, savedTag)) {
                Fragment.SavedState fss = mSavedState.get(position);
                if (fss != null) {
                    fragment.setInitialSavedState(fss);
                }
            }
        }
```

Note that we also add the fragment using the [`FragmentTransaction#add (int containerViewId, Fragment fragment, String tag)`][1] signature - that is, we actually use the tag when adding our fragment:

```
        mCurTransaction.add(container.getId(), fragment, fragmentTag);

        return fragment;
    }
```

In `destroyItem` we just mirror what's done to `mSavedState`. We pad it out if necessary...

```
        if (DEBUG) Log.v(TAG, "Removing item #" + position + ": f=" + object
                + " v=" + ((Fragment)object).getView() + " t=" + fragment.getTag());
        while (mSavedState.size() <= position) {
            mSavedState.add(null);
            mSavedFragmentTags.add(null);
        }
```

...then we save the tag at that location.

```
        mSavedState.set(position, mFragmentManager.saveFragmentInstanceState(fragment));
        mSavedFragmentTags.set(position, fragment.getTag());
        mFragments.set(position, null);

        mCurTransaction.remove(fragment);
    }
```

Finally we have the `saveState` and `restoreState` methods. These are pretty trival changes. In `saveState` we put the saved fragment tags into the `Bundle`:

```
state.putStringArrayList("tags", mSavedFragmentTags);
```

And then in `restoreState`, surprise, we restore the saved fragment tags from the bundle:

```
mSavedFragmentTags = bundle.getStringArrayList("tags");
```

Two last things to do:

- Change your subclass to override your new, fixed, adapter (rather than the one in the support library)
- Remember to **override `getTag(int position)`** to return a unique tag for each fragment

If you forget either of these things, you'll just have the same behaviour as before. In my [demo app](https://github.com/adamsp/FragmentStatePagerIssueExample), this would look something like the following - obviously you'll need to adjust this to suit your own data source:

```
@Override
public String getTag(int position) {
    return labels[position];
}
```

And that's it! Those're the changes we need to make to the `FragmentStatePagerAdapter` for it to stop misbehaving and restoring the wrong state to fragments in different locations.

You can find a complete example of this fixed class [in the sample project](https://github.com/adamsp/FragmentStatePagerIssueExample/blob/master/app/src/main/java/com/example/fragmentstatepagerissueexample/app/FixedFragmentStatePagerAdapter.java). There's some lines commented out in the adapter in `MainActivity`; just swap the class definition and uncomment the method and you've magically got an adapter working as expected!

# That's great! Any gotchas?

Sure are.

- Remember to override `getTag(int position)`, or else you'll continue to see the old behaviour.
- `getTag(int position)` must return a _unique_ tag for each fragment.
- If your `FragmentStatePagerAdapter` is an inner class of a `Fragment`, _and_ you're calling that fragments `getTag()` method, then that call will now give a compile error. You'll need to change it to `MyParentFragment.this.getTag()` instead, _or_ change the fixed adapter to use a different method signature - `getFragmentTag(int position)`, perhaps.
- You won't automatically receive bug fixes and updates to the `FragmentStatePagerAdapter` when the support library updates. This is unlikely to be an issue though - it's been in source for [over 18 months as of this writing](https://android.googlesource.com/platform/frameworks/support/+log/refs/heads/master/v4/java/android/support/v4/app/FragmentStatePagerAdapter.java) (Feb 20, 2014) without a single change (the [v13 version, too](https://android.googlesource.com/platform/frameworks/support/+log/refs/heads/master/v13/java/android/support/v13/app/FragmentStatePagerAdapter.java)).
- If you want to use a different key to put the saved tags into/restore from the bundle (other than just "tags" like I've used here), make sure it doesn't start with "f" - note how a little further down in the `restoreState` method it checks for keys starting with "f" and assumes they're fragments!

# Thanks! You saved the day.

No worries! Maybe one day you'll write a post on how to fix some obscure bug that I'm having trouble with.

If you have any questions, you can ask me on [Twitter](https://twitter.com/adamsnz), or [Google+](https://plus.google.com/+AdamSpeakman), or open an issue on (or send a pull request to) the [Github project](https://github.com/adamsp/FragmentStatePagerIssueExample).


[1]: https://developer.android.com/reference/android/support/v4/app/FragmentTransaction.html#add(int, android.support.v4.app.Fragment, java.lang.String)