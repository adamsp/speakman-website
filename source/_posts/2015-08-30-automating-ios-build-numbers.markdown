---
layout: post
title: "Automating iOS build numbers"
date: 2015-08-30 13:21
comments: true
categories: ios xcode xcodebuild automation
---

I recently encountered some problems where I was accidentallly duplicating build numbers for our iOS app. At [Bridgit](http://gobridgit.com) we're big fans of automation, so I went about finding a way to avoid this human error and let the machines do the work for me.

<!-- more -->

We use Twitter's [Fabric](http://fabric.io) platform to distribute our iOS app for internal testing. The "Beta" dashboard looks a little like this:

{% img /images/ios-automation/fabric-beta-dashboard.png %}

If you aren't using this yet, I can't recommend it enough - I can distribute a beta build to a select set of testers immediately after archive. I don't have to deal with iTunes Connect, and as you can see, I get some great info on that distribution, such as who installed it, who's experienced a crash, and more.

As you can see, each build I send out has a build number attached to it - this is set by `CFBundleVersion` in your app's Info.plist file, or alternately by adjusting the value of the "Build" field in the "General" tab of your app target configuration.

You might also have noticed that some of the builds in that screenshot have the same number. Whoops. Bit difficult to check if someone's on the latest version if the build number didn't change! At the time, my build process was "Remember to increment build number, commit changes, press Archive, distribute build". You can see how that might fall down - any process that includes "Remember to X" is going to fall over eventually.

# Avoiding human error through automation

To avoid this kind of human error, we now have a handy script we've injected into our build process which automates the process of incrementing the build number.

``` sh increment-build-number.sh https://gist.github.com/adamsp/da0e0bab0e25412779ff gist
#!/bin/sh

if [ $CONFIGURATION == Release ]; then
if [[ -n $(git status --porcelain) ]]; then
echo "Repository is dirty, commit your changes.";
exit 2
fi
echo "Incrementing build number..."
plist=${PROJECT_DIR}/${INFOPLIST_FILE}

# increment the build number (ie 115 to 116)
buildnum=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${plist}")
if [[ "${buildnum}" == "" ]]; then
echo "No build number in $plist"
exit 2
fi

buildnum=$(expr $buildnum + 1)
/usr/libexec/Plistbuddy -c "Set CFBundleVersion $buildnum" "${plist}"
echo "Bumped build number to $buildnum"

git add ${plist}
git commit -m "Increment build number ($buildnum)"
git tag build-$buildnum

else
echo $CONFIGURATION " build - Not bumping build number."
fi
```

This script does the following:

- checks to see if the current build is a Release (archive) build
	- if NOT a Release build, do nothing (we don't want to increment the build number for every Test or Debug build)
- checks to see if `git status --porcelain` prints anything
	- if something is printed, then the git repository is dirty and we shouldn't be doing a build, abort the build
- checks for an existing build number
	- if no existing build number, abort the build
- increments the build number
- commits the build number increment change to git
- tags the new commit with the build number so we can easily find it again later

Much of this I pieced together from parts of [this StackOverflow question and its answers](http://stackoverflow.com/q/9258344/1217087).

To use this, make sure it's executable (`chmod +x increment-build-number.sh`), then add a new "Run Script Phase" to the "Build Phases" tab of your target configuration and drop in the path. I left the script at the top level of my project directory so my path is `${PROJECT_DIR}/increment-build-number.sh`.

To test that it's working, make a change, don't commit it, and attempt to build an archive - it should fail. Undo your changes, build an archive, and if it succeeds you should see a new tag listed when you run `git tag --list`.

# Benefits

Now I can guarantee a new build number for every archive I distribute. Every time a tester reports a problem or I get a crash report, I can confirm which version they're running without wondering if it's _actually_ the latest build or not. I no longer get submission rejections from the App Store because I forgot to increment the build.

Importantly, I now have git tags for every build - so if a problem shows up, I can easily find the exact place in our git history where it was introduced.

# Caveats

This script works well as a starter solution, but it has a few caveats. I'll address some of these in a future post - however if you're the only developer working on a simple application, this example is likely fine to use as-is.

- build numbers can be duplicated if multiple developers are doing releases
- build numbers can be duplicated if releases happen on multiple branches
- if the git tag already exists, by the time this fails the commit has already happened and the archive process completes (but applying the tag fails quietly)
- fails to consider different schemes and special behaviour you may want for those
- doesn't push the tag to remote

These are all things we can fix (either through process or further automation) - ~~I'll go over these fixes in a later post~~.

**Edit Feb 22nd 2016:** Well, I never got around to fixing the above caveats. I'm no longer with Bridgit, and never had the chance to fix the above (with the exception of the schemes issue). My entire time with Bridgit I was either the sole iOS developer, or at least the only person doing releases - so I didn't have to worry about conflicts. My recommendation is to simply use the current epoch for build numbers (which you can acquire through `date +"%s"`), and to have a dedicated build/release machine. 

For dealing with schemes, if I recall correctly I had 4 schemes - Debug, Development, Staging, Release. Each of these had a regular build configuration, and an archive configuration. I'd only increment build numbers if the build configuration name included "Archive", otherwise I'd bail out (avoiding incrementing the build number every time you ran the app on the simulator!). We also used these configurations to enable analytics only on archive.