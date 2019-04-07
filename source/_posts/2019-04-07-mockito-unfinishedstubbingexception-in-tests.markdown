---
layout: post
title: "Mockito UnfinishedStubbingException in tests"
date: 2019-04-07 13:05
comments: true
categories: mockito kotlin java android
---

Ever wonder why Mockito will occasionally give you an `UnfinishedStubbingException` even though you _clearly_ finished the stubbing?

For example, the following code will fail at runtime (`mockChannel` has been setup earlier):

``` kotlin
whenever(mockChannelNameProvider.nameForChannel(mockChannel))
    .thenReturn(mockChannel.id())
```

With an exception like this:

```
org.mockito.exceptions.misusing.UnfinishedStubbingException: 
Unfinished stubbing detected here:
-> at ExampleFailingTestKotlin.setupChannelName(ExampleInterfacesTest.kt:30)

E.g. thenReturn() may be missing.
Examples of correct stubbing:
    when(mock.isOk()).thenReturn(true);
    when(mock.isOk()).thenThrow(exception);
    doThrow(exception).when(mock).someVoidMethod();
Hints:
 1. missing thenReturn()
 2. you are trying to stub a final method, which is not supported
 3: you are stubbing the behaviour of another mock inside before 'thenReturn' instruction is completed
```

This is a very good exception message. It gives you some common examples of what you might have done wrong, and how to fix them. However, our code doesn't match any of the examples.

<!-- more -->

If we look at the generated Java for this (`Tools > Kotlin > Show Kotlin Bytecode > Decompile`), it _still_ looks like it should work - we definitely finish the stubbing:

``` java
Channel var10001 = this.mockChannel;
if (var10001 == null) {
  Intrinsics.throwUninitializedPropertyAccessException("mockChannel");
}

OngoingStubbing var2 = Mockito.when(var1.nameForChannel(var10001));
var10001 = this.mockChannel;
if (var10001 == null) {
  Intrinsics.throwUninitializedPropertyAccessException("mockChannel");
}

var2.thenReturn(var10001.id());
```

So why do we get an `UnfinishedStubbingException`? *Because we're accessing a mock before we finish the stubbing.*

The failure happens on this line from the decompiled Kotlin bytecode:
``` java
var2.thenReturn(var10001.id());
```

Let's make this a little clearer by using descriptive names:
``` java
ongoingStubbing.thenReturn(mockChannel.id());
```

You can break this apart a little further:
``` java
String id = mockChannel.id();
ongoingStubbing.thenReturn(id);
```

So we have a reference to an `OngoingStubbing`. Internally, Mockito statically maintains a reference to a `MockingProgress`. When we access the mock (`mockChannel.id()`) after we've already started the stubbing, Mockito goes off to the `MockingProgress` and [calls through to a `validateState()` method](https://github.com/mockito/mockito/blob/49e07acc30fb486a8af773977e461cf4d1c876ec/src/main/java/org/mockito/internal/handler/MockHandlerImpl.java#L64), which does this:

``` java
public void validateState() {
  validateMostStuff();

  //validate stubbing:
  if (stubbingInProgress != null) {
      Location temp = stubbingInProgress;
      stubbingInProgress = null;
      throw unfinishedStubbing(temp);
  }
}
```

Because a stubbing is still in progress, we get an `UnfinishedStubbingException`. 💥

We can fix this by pulling the variable out of the mock on the line before we start the stubbing:
``` kotlin
val channelName = mockChannel.id()
whenever(mockChannelNameProvider.nameForChannel(mockChannel)).thenReturn(channelName)
```

Of course, make sure to comment _why_ you're doing this for the next developer who comes along and tries to simplify this by inlining the variable.

Now that we see why it's happening, it makes sense. Accessing a mock while setting up a different one is a bit of a code smell - they should probably be accessing some constant value. One of the best ways to prevent this situation is to use fakes not mocks for your models. Obviously, this isn't always easy though - you might have legacy concerns that prevent this or you might need to make sure that you return the same thing from two different interfaces.

This can be a very confusing error to debug, especially when it's deep in some utility or setup method (where it might not even be obvious that you're accessing something on a mock), or when you're in the process of converting some legacy code. Next time you encounter it, consider whether you can do some refactoring to make it harder to hit.

You can find the [source code for this post here](https://github.com/adamsp/mockito-tests).