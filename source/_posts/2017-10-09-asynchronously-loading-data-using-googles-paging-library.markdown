---
layout: post
title: "Asynchronously loading data using Googles Paging Library"
date: 2017-10-09 14:42
comments: true
categories: android kotlin paging-library
---

The recently released [Paging Library](https://developer.android.com/topic/libraries/architecture/paging.html) from Google gives you an easy way to page data into memory off of the main thread. If you want to use it with [Room](https://developer.android.com/topic/libraries/architecture/room.html), then the built-in support makes it trivial. However, if you'd like to page data that exists elsewhere - from the network or disk, for example - then you have to do a little extra work.

Here I demonstrate how to take existing code that loads a list of screenshots from disk and convert it to load asynchronously using the Paging Library. This example could easily be adapted for network calls.

<!-- more -->

Throughout this post we'll be using a `Screenshot` class defined as follows:

``` kotlin
@Parcelize
class Screenshot(val uri: Uri, val width: Int, val height: Int) : Parcelable
```

You will also need to import the library:

```
implementation "android.arch.paging:runtime:1.0.0-alpha2"
```

## Existing code

When the app launches, it shows the user a list of images from a directory they supply during setup. My existing code was a simple repository that loaded _all_ screenshots (as a Uri and width/height values) from this directory via Android's storage access framework. The code was similar to the following:


``` kotlin
override fun allScreenshots(): List<Screenshot> {
    val screenshots = documentsAtUri(screenshotDirectory)
    return screenshots.map {
    	getScreenshotFromUri(DocumentsContract.buildDocumentUriUsingTree(it.path, it.id))
    }
}

private fun getScreenshotFromUri(uri: Uri): Screenshot {
    val (width, height) = getDimens(uri)
    return Screenshot(uri, width, height)
}

private fun getDimens(uri: Uri): Pair<Int, Int> {
    val opts = BitmapFactory.Options()
    opts.inJustDecodeBounds = true
    val parcelFileDescriptor = contentResolver.openFileDescriptor(uri, "r")
    val fileDescriptor = parcelFileDescriptor!!.fileDescriptor
    BitmapFactory.decodeFileDescriptor(fileDescriptor, null, opts)
    return Pair(opts.outWidth, opts.outHeight)
}
```

As you can see, we have to go to disk to get information about every screenshot. This is expensive! On my test device I've only got around 100 screenshots - on a device that's been around longer a user could have many hundreds or thousands of screenshots in this folder. Rather than loading these all up front, I need to load these asynchronously. In addition, since these are in a list there's a high likelihood that the items further down the list won't even be needed. The Paging Library helps with these problems.

## Paging Library Fundamentals

The Paging Library has 3 different "levels" that build on top of each other.

At the base, we have a kind of [`DataSource`](https://developer.android.com/reference/android/arch/paging/DataSource.html). This can be either "keyed" (such that you need to know about the item at index N-1 in order to know about the item at index N - like a linked list), or "tiled" (such that you can access elements at arbitray indices - like an array list).

Above that, we have a [`PagedList`](https://developer.android.com/reference/android/arch/paging/PagedList.html), which as its name suggests, is a list that pages its data in from a `DataSource`.

Finally we have the [`PagedListAdapter`](https://developer.android.com/reference/android/arch/paging/PagedListAdapter.html), which is a `RecyclerView.Adapter` that neatly wraps a `PagedList`, calling the correct `notifyItem...` methods for you as your data changes (when you call `setList` with a new `PagedList`) or loads in. This is fairly standard `RecyclerView` boilerplate. If you need some custom behaviour, you can duplicate its functionality - it's just a handy wrapper around the [`PagedListAdapterHelper`](https://developer.android.com/reference/android/arch/paging/PagedListAdapterHelper.html).

## Constructing a Data Source

A `DataSource` is reasonably simple. For a list like this, we implement a `TiledDataSource`, doing the expensive disk IO in the `loadRange` method. The `PagedList` will call this from a background thread when it is time to load a new page of data.

Note that it does _not_ clamp ranges for you - so if you have 10 items and a page size of 6, your second page will be `startPosition = 6` and `count = 6` - which will give you an `IndexOutOfBoundsException`. Make sure to clamp your inputs as I do here.

``` kotlin
val screenshots = documentsAtUri(loadScreenshotDirectory())

val dataSource: DataSource<Int, Screenshot> = object : TiledDataSource<Screenshot>() {
    override fun countItems(): Int {
        return screenshots.size
    }

    override fun loadRange(startPosition: Int, count: Int): List<Screenshot> {
    	val end = minOf(startPosition + count, countItems())
    	return screenshots.subList(startPosition, end).map {
            getScreenshot(DocumentsContract.buildDocumentUriUsingTree(it.path, it.id))
        }
    }
}
```

## Building a Paged List

For my use-case, 8 elements on a 'page' was sufficient. I'm showing elements in a 2-column list; most of the elements are around half the window height. You'll need to decide what works well for you.

Note that here we use the default prefetch distance of `pageSize` - that is, as soon as the first item in a given page of data is requested, the next page will begin loading. Depending on your data, you may want this to be smaller or larger.

We also enable placeholders (this is actually enabled by default). Since we know exactly how many elements are going to be in our list (we have Uris for every screenshot, even if we don't have any details about that screenshot yet) we can use null placeholders while the images load - helping avoid weird scrollbars. Our `onBindViewHolder` has to deal with this later. I'd recommend [reading the `PagedList` docs](https://developer.android.com/reference/android/arch/paging/PagedList.html) - they go into more detail on placeholders.

You need to supply two [`Executor`](https://developer.android.com/reference/java/util/concurrent/Executor.html)s - one for posting back to the main thread, and another for background work. In this example we create a main thread `Handler` and post events to it directly, but our disk IO `Executor` is injected from elsewhere.

Finally, this code has one subtle gotcha - the first two pages will be loaded immediately on whatever thread `build()` is called from! From the docs:

> Creating a PagedList loads data from the DataSource immediately, and should for this reason be done on a background thread. The constructed PagedList may then be passed to and used on the UI thread. This is done to prevent passing a list with no loaded content to the UI thread, which should generally not be presented to the user.

In this case, we'll be going to disk 16 times (8 for the first page, and then another 8 as the second page is pre-fetched). I address this later when I wire everything together.

``` kotlin
val mainHandler = Handler(Looper.getMainLooper())

val pagedList = PagedList.Builder<Int, Screenshot>()
    .setDataSource(dataSource)
    .setMainThreadExecutor({ mainHandler.post(it) })
    .setBackgroundThreadExecutor(diskExecutor)
    .setConfig(PagedList.Config.Builder()
            .setPageSize(8)
            .setEnablePlaceholders(true)
            .build())
    .build()
```

## Adding the Adapter

The simplest part of all. We just extend `PagedListAdapter`, supplying a simple `DiffCallback` for comparing `Screenshot` objects, and implement `onBindViewHolder` and `onCreateViewHolder` like normal.

Note if you have custom logic (such as a custom `BindingAdapter` - not shown here) you need to be aware that the object returned from `getItem` _can be_ `null` - these are the placeholders we enabled earlier, and will be `null` while the data at that index loads. If your page sizes are appropriate, receiving a `null` object will be rare, but you _must_ handle it.

``` kotlin ScreenshotPickerAdapter.kt
val DIFF_CALLBACK = object : DiffCallback<Screenshot>() {
    override fun areItemsTheSame(oldItem: Screenshot, newItem: Screenshot): Boolean {
        return oldItem.uri == newItem.uri
    }

    override fun areContentsTheSame(oldItem: Screenshot, newItem: Screenshot): Boolean {
        return oldItem.uri == newItem.uri
    }
}

class ScreenshotPickerAdapter(val clickHandler: ScreenshotPickerSelectionHandler)
    : PagedListAdapter<Screenshot, ScreenshotViewHolder>(DIFF_CALLBACK) {

    override fun onBindViewHolder(holder: ScreenshotViewHolder, position: Int) {
        val screenshot = getItem(position)
        holder.screenshot = screenshot
    }

    override fun onCreateViewHolder(parent: ViewGroup?, viewType: Int): ScreenshotViewHolder {
        val binding: PickerListItemBinding = DataBindingUtil.inflate(
        	LayoutInflater.from(parent?.context), R.layout.picker_list_item, parent, false)
        return ScreenshotViewHolder(binding, clickHandler)
    }
}
```

## Wiring it all up

Now we have all the pieces we can put them together. Note that I supply an async callback for loading the screenshots - we use the disk executor we supply in the constructor to do the actual building (since this loads the first page or more, as mentioned above!) and then set the result on our list once that load has finished.

For brevity, this code doesn't consider configuration changes or other kinds of activity destruction.

``` kotlin Executors.kt
// Define a disk IO executor that can be re-used elsewhere
val diskExecutor = Executors.newFixedThreadPool(2)
```

``` kotlin MainActivity.kt
var screenshotLoader: ScreenshotLoader? = null
var adapter: ScreenshotPickerAdapter? = null

override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_main)
    screenshotLoader = SAFScreenshotLoader(contentResolver, diskExecutor)
    adapter = ScreenshotPickerAdapter(this)
    val recycler = findViewById(R.id.main_recycler) as RecyclerView?
    recycler?.layoutManager = GridLayoutManager(this, 2)
    recycler?.adapter = adapter
    loadScreenshots()
}

private fun loadScreenshots() {
    screenshotLoader?.allScreenshots({
        // We could explode here if the activity has been killed
        runOnUiThread {
            adapter?.setList(it)
        }
    })
}
```

``` kotlin SAFScreenshotLoader.kt
override fun allScreenshots(resultListener: (PagedList<Screenshot>) -> Unit) {
    // This assumes retrieving the Uris is cheap - this whole block could be moved off thread
    val screenshotUris = documentsAtUri(loadScreenshotDirectory())
    val dataSource: DataSource<Int, Screenshot> = object : TiledDataSource<Screenshot>() {
        override fun countItems(): Int {
            return screenshotUris.size
        }

        override fun loadRange(startPosition: Int, count: Int): List<Screenshot> {
            val end = minOf(startPosition + count, countItems())
            return screenshotUris.subList(startPosition, end).map {
                getScreenshot(DocumentsContract.buildDocumentUriUsingTree(it.path, it.id))
            }
        }
    }
    val builder = PagedList.Builder<Int, Screenshot>()
            .setDataSource(dataSource)
            .setMainThreadExecutor({ mainHandler.post(it) })
            .setBackgroundThreadExecutor(diskExecutor)
            .setConfig(PagedList.Config.Builder()
                    .setPageSize(8)
                    .setEnablePlaceholders(true)
                    .build())
    // Note the actual construction happens on an IO thread - the build() call goes to disk
    diskExecutor.execute {
        resultListener(builder.build())
    }
}
```

## Gotchas

- You may have to specify a `minHeight` on your list items, or otherwise specify the height when a placeholder is used. If you don't, the adapter will query for (and the list will try to load) your whole list of 0-height items.
- Don't forget the first page is loaded when you call `PagedList.Builder.build()` - do this off the main thread!
- Experiment with page sizes and prefetch windows. This is entirely dependent on your data.
- Already loaded objects are **not** unloaded. If the user scrolls to the bottom of the list, the first items stay in memory. This is potentially a problem if your objects are large, or your list is long. Here I let [Picasso](http://square.github.io/picasso/) load (and unload) the actual memory-intensive bitmaps for me. Storing a list of Uris is cheap.
- You **must** handle null objects returned from `getItem` if you enable placeholders, even if you never encounter them in your testing.
- The `loadRange` call is not bounded to the size of the list; you need to do this yourself. It will happily handle results smaller than the requested count, however (i.e. when you're at the end of the list).
- If you're using [`LiveData`](https://developer.android.com/reference/android/arch/lifecycle/LiveData.html), look into [`LivePagedListProvider`](https://developer.android.com/reference/android/arch/paging/LivePagedListProvider.html) as it will do most of this overhead for you.
- The library is still in alpha at the time of this writing; the APIs described here could still change before release.
