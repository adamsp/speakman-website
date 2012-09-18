---
layout: post
title: "Setting up Octopress on Github Pages"
date: 2012-09-11 20:22
comments: true
categories: 
---

There's a lot of good information out there already on setting up Octopress on Github. The [Octopress documentation](http://octopress.org/docs/deploying/github/) covers the subject in depth, as do assorted blog posts. However, perhaps it's because I was drinking while doing it, or perhaps it was because I missed something while reading the guides, or my poor mental model of how things were supposed to work, or even that it was late at night, but I had a lot of trouble setting up [What's Shaking, NZ?](http://www.whatsshaking.co.nz) on Github Pages.

<!-- more -->

A few things to note:
 
1. A lot of what I've done with setting up this website is completely new to me. I've never edited CSS before, for example -- or ever owned a domain name. So if something is obvious to most, apologies if an explanation may seem unnecessary. I especially apologise if an explanation is wrong! Please let me know.
2. If you want a guide to setting things up, this isn't it. A lot of things I did here are _wrong_. This post is simply to point out some of the things I struggled with, in the hope that pointing out the right way to do things may be of help to someone else some day.

Now, on to the post!

### Intent

My intent was to host the website as a project page on a Github repo, using a custom domain. This repository would consist of a `master` branch with the source on it, and a `gh-pages` branch with the website on it. From there, I could have the www.whatsshaking.co.nz domain point at the right place and everything would all work splendidly. I spent a fair bit of time playing around with colours and layout and resizing locally (resizing the header was only possible thanks to [Lee at Big Dinosaur](http://blog.bigdinosaur.org/changing-octopresss-header/)). When it was at a this-sucks-less-than-everything-else-I've-tried stage, I decided it was time to put it up online.

I spent a bit of time poring over the [Octopress documentation](http://octopress.org/docs/deploying/github/) as well as [this post by Rob Dodson](http://robdodson.me/blog/2012/04/30/custom-domain-with-octopress-and-github-pages/). I figured I was armed with enough knowledge to get this to work first time.

My test setup on my local machine looked something like this:

- Octopress cloned into `~/Sites/wsnz` using the command on the site
- [POW](http://pow.cx/) running so I could access http://wsnz.dev locally and see the changes to my site as I made them, after running `rake watch`

What I wanted, was this:
- Octopress WSNZ site in `~/Code/wsnz-website` with source on `master` branch and easy deployment to `gh-pages` branch
- POW running the same as above, for easy local development

So, with beer in hand and the internet at the ready I embarked on this adventure.

### Following instructions

First of all, I wanted my code in a different place locally. So I created the repository on the Github site ([adamsp/wsnz-website](https://github.com/adamsp/wsnz-website)) and cloned to `~/Code/wsnz-website` using the 'Clone in Mac' button and the Github application. Then through the OS X Finder I copied the contents of `~/Sites/wsnz` into `~/Code/wsnz-website`. Importantly, this means I no longer have the original .git folder, so that explains why the [wsnz-website repository](https://github.com/adamsp/wsnz-website) has no commit history (<s>where as the [repo for this site](https://github.com/adamsp/adamsp.github.com) is a 'proper' fork and does have the commit history</s> **Edit 18 Sep 2012:** [This site](https://github.com/adamsp/speakman-website) ended up copy/pasted from that linked repo).

Now my code was in the right place, I went ahead and did some other modifications. I changed my `_config.yml` file so that the URL property pointed at the domain, `url: www.whatsshaking.co.nz`, I added a [.gitignore](https://github.com/dstufft/octopress/blob/9f40242b1e7eb0098f0ef3c508c7bed7e647b982/.gitignore), added a Google Analytics ID, etc. I also did `echo 'www.whatsshaking.co.nz' >> source/CNAME`, as instructed in the guides, so I had a CNAME file with my site URL in it.

I now ran `rake setup_github_pages` (with the git endpoint as `git@github.com:adamsp/wsnz-website`) -- this changed my `_config.yml` and `Rakefile`. This is wrong! 

When I ran `rake deploy` I ended up with a broken website. I figured I should be able to see it at http://adamsp.github.com/wsnz-website -- but that didn't work. This was confusing, as everything appeared to be right on the `gh-pages` branch.

### Fixing problems

I was looking through HTML in the `gh-pages` branch when I realised that the files weren't at root. Checking back in my source again, it looked like everything in the config files was prefixed with `wsnz-website/`!

The `setup_github_pages` command changed all the URLs to be prefixed with `wsnz-website/`. I had to go through and edit these out. So you should still have the following settings in these files:
``` css _config.yml
subscribe_rss: /atom.xml
root: /
destination: public
```

``` css Rakefile
public_dir = "public"
```

``` ruby config.rb
    http_path = "/"
    http_images_path = "/images"
    http_fonts_path = "/fonts"
    css_dir = "public/stylesheets"
```
But oddly enough, things still weren't working. Turns out, I had to leave the URL property in `_config.yml` as `url: http://adamsp.github.com/wsnz-website`.

Once I did this and redeployed, everything worked as expected. I updated my link in `~/.pow` to point to `~/Code/wsnz-website` and I could access my site for local development again. Pushing blog posts and changes is now as simple as `rake generate` then `rake deploy`. Easy.

### Specific issues

Anyway, after all of that, these are the issues I had, and their fixes/correct settings:

- The settings in `_config.yml` *require a space after the colon* or else the generate command fails.
- If you're updating files in the sass folder and things don't appear to be changing, you may need to delete `.sass_cache`.
- The `url` setting in `_config.yml` is the Github pages URL -- eg `url: http://adamsp.github.com/wsnz-website`. This is true even if using a custom domain. See [this commit](https://github.com/adamsp/wsnz-website/commit/44e66db6a834624089e06bbd9b60779881045aba) for what I mean.
- The paths in `_config.yml`, `config.rb` and `Rakefile` should *not* contain your sites repository name. eg `destination: public` and not `destination: wsnz-website/public`. The `rake setup_github_pages` command may put these settings there.
- The `CNAME` file should exist under the source folder, and then when deployed it will exist in the root of your `gh-pages` directory. This is required.
- [Setting up the DNS entries](http://octopress.org/docs/deploying/github/#custom_domains) is also required. With the `CNAME` file present you cannot access the site at the Github address. Note that you should just point it to `http://username.github.com` rather than `http://username.github.com/project-page`.

Again, I must emphasise that most of this is fairly new to me. I'm sure most of these things are common knowledge, but not to me - and that means probably not to someone else.
