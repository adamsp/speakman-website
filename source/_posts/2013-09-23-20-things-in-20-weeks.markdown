---
layout: post
title: "20 Things in 20 Weeks"
date: 2013-09-23 19:39
comments: true
categories: 20-things-20-weeks
published: false
---

Recently I've been realising more and more how much time I spend doing things that aren't productive. Watching TV, playing video games, etc. While some down time is important, I've got all these ideas rattling around my head that I'd love to work on, but I keep putting off until some ever-distant 'later'. So I've decided that for the next few months I'd like to be (more) productive, and I'm setting myself a challenge. I plan on implementing **20 Things in 20 Weeks**. Some of these ideas are tiny apps, or blog posts, or scripts, and will only take a few hours to complete. Others are rather large and may take a few weeks of solid work.

<!-- more -->

There are a few reasons behind doing this. I'd like to actually have something to show for my downtime - I've had a bunch of these ideas for a long time now and have never gotten around to doing them. I want to keep learning - and the best way to learn is to write code and make mistakes. My software design skills (and UI design, for that matter) are somewhat lacking - the more mistakes I make, the more things I know not to do in the future. And I simply want to challenge myself.

I intend to complete all of this around my other obligations - working full time, obviously, and spending time with my partner, friends and family - so it may be a bit of a stretch, but I'm curious to see what I can achieve if I put my mind to it. At the very least, I'll have _something_ to show for my time at the end of it.

I've written a few loose 'rules' around what a Thing is, whether it counts towards the 20, how to keep track of myself, etc:

- A Thing is an idea for an app, a control, a library, _something_ that is interesting, useful, helpful or simply helps me learn something new.
- A Thing doesn't have to be unique (for example a Stopwatch app is not unique in the slightest) but I have to learn, use or produce something new each time.
- I might get part way through and decide something is "too much" to get done in the time frame, or I might simply not want to do it anymore - I can swap that idea out for something else, or ditch it completely. 
- If I can extract something out of any partially completed work into a useful control or a library for something then that counts as a Thing.
- There is no rule that I must only work on one Thing at a time, or on the Things in any specific order. 
- I don't have to produce a Thing every week, or only produce one Thing in any given week. 
- Things produced in earlier weeks can be used to help build things in later weeks. 
- I must detail at the end of each week what I have done - this should be in the form of a blog post, where I can go into detail, or just provide an overview, depending on how interesting the Thing(s) was/were. 
- If I make a Thing worthy of its own blog post, I should write a post for that as well as the weekly one. The blog post about the Thing is considered part of that Thing. 
- Some of the Things listed below __are__ blog posts - this is OK. The 'post about a Thing' described in the prior point is a retrospective post, rather than a pro-active post whose intent is to be a Thing.

I've written up a quick list of ideas of Things I can do over this time. This list will change - I will update it as I go with links to posts, links to finished products, strike-throughs as I drop things and additions as I think of new Things.

1. Common Android libraries base/sample project that people can copy (including ActionBarSherlock, HoloEverywhere, Guava, etc), with examples, plus rename script (for renaming all the namespaces and the app name etc) - potentially implemented as an Android Studio template?…

2. Stopwatch app with Start/Stop timer and Countdown functionality

3. Road Rules Comparison website/app for saying "I'm from New Zealand, what are the road rules in Canada that are different?" and displaying differences

4. Diary app/website, completely private, for recording what you did that day, including the ability to check in places (privately), what you learned, add pictures, etc, and a "What happened to me on this day last year/last month/last week" function

5. Text based Twitter client (Yatta - Yet another text-based Twitter app) designed specifically for not consuming much data - no pictures, manual refresh only, no link auto-expansion (Twitter might do this for you?…) etc

6. A Pinterest-style Android list view, implemented properly so you just attach a ListAdapter and you're away (Attempted - [Blog](../../../10/07/20-things-week-2/) - Etsy have [built a _far_ superior one](https://github.com/etsy/AndroidStaggeredGrid) though, so I doubt I'll ever touch this again)

7. LeapMotion Windows controller to maximise/minimise/move windows left/right

8. Add a widget to Whats Shaking, NZ? ([Blog](../../../../2014/01/01/20-things-weeks-13-and-14/), [Github](https://github.com/adamsp/wsnz-android/commit/813d1ec9a60c01277dad256877aacfe5b4e3178a))

9. Sudoku solver (in Python?) ([Blog](http://speakman.dev/blog/2014/01/20/20-things-week-17/), [Github](https://github.com/adamsp/sudoku-solver), and even a [Google App Engine implementation](https://github.com/adamsp/sudoku-solver-gae)!)
 
10. Currency formatter class/tests/examples/blog posts ([Blog post](../../../10/21/android-currency-localisation-hell/), [Github](https://github.com/adamsp/CurrencyFormattingDemo))

11. App that shows current/max/min speed - should be ideal for using RxJava for streaming location data?

12. 'Cartoonify' app that takes a photo + converts it to a cartoon

13. What's Shaking, NZ? for iOS (partly written already)

14. Figure out how to fix the Twitter plugin on the side of this website. ('Fixed' it by [deleting it](https://github.com/adamsp/speakman-website/commit/7b87a9597e0505c668bd65a4114b3009452fc2d9) - updated the theme at the same time, woo!)

15. CV/Resume app, with my work history, links to profiles, Twitter stream, G+ stream, etc

16. Basic RSS reader, maybe?…

17. Basic flash cards app - math, chemistry, physics, etc.

18. Social running app, like geocaching you've gotta find specific locations and check-in there for points, get more points the more people check in to your submitted favourite running spots

19. Time localisation differences for Samsung (and other?…) devices examples + blog post

20. <del>Wedding website for my friends Michael and Rebecca</del> (Oops, they got married!)

21. Create a ‘global’ version of WSNZ + use Gson instead of manual parsing (Started - [Blog](../../../../2014/01/01/20-things-weeks-13-and-14/), [Github](https://github.com/adamsp/WhatsShaking))

22. Open source Android app licenses page example - Settings app page comes from a file and that file is created during build - what about one-person apps where your build process is File -> Export? ([Blog post](../../24/android-open-source-licenses-page/), [Github](https://github.com/adamsp/AndroidLicensesPage))

23. A social network specifically for sharing cat pictures, because cats are awesome.

24. A class for parsing WCF formatted DateTime objects in Java ([Blog](../../../10/14/20-things-week-3/), [Gist](https://gist.github.com/adamsp/6914482)).

25. Twitter-feed Android Daydream, “Dream In Tweets” ([Play Store](https://play.google.com/store/apps/details?id=nz.net.speakman.android.dreamintweets), [launch blog entry](../../../10/28/20-things-week-5/), [chasing down KitKat bugs blog entry](../../../12/02/20-things-week-10/), and [still chasing down KitKat bugs blog entry](../../../12/09/20-things-week-11/), [Github](https://github.com/adamsp/DreamInTweets))

