---
layout: post
title: "Tensorflow in Windows Bash"
date: 2017-01-24 21:27
comments: true
categories: python windows tensorflow
---

My first job out of university was at a startup doing natural language processing (NLP). Recently I've been rekindling my interest in machine learning, and have been playing with the [Tensorflow](https://www.tensorflow.org/) library from Google. I work on a Mac, but at home I'm switching between a Mac and a PC - and ideally I'd like things to just work on whatever machine I'm on. The Tensorflow [setup guide](https://www.tensorflow.org/get_started/os_setup) says it requires Python 3.5 for Windows, but I'm using Python 2.7 on my Mac and would like to be able to use files across platforms.

Here's a quick intro to getting set up with Tensorflow for Python 2.7 on Windows (using the recently released [Bash on Windows](https://msdn.microsoft.com/en-us/commandline/wsl/about)).

<!-- more -->
# Step 1 - Install Bash for Windows

This is pretty trivial. Just [follow the instructions](https://msdn.microsoft.com/en-us/commandline/wsl/install_guide). I installed this on a Windows 10 64 bit machine with no problems.

# Step 2 - Install Tensorflow

Now you have a bash shell (which comes with Python 2.7.4), we have to intall & upgrade pip (Tensorflow requires pip 8.1 or later):

```
sudo apt-get install python-pip
sudo pip install --ugprade pip
source ~/.bashrc
sudo pip install tensorflow
```

You can test that everything worked by opening up a Python interpreter (ie, just type `python` and hit enter) then importing Tensorflow:

```
import tensorflow as tf
```

If you get no output, everything worked! `exit()` that and carry on.

# Step 3 - Usage

If you'd like to edit your files in the shell, you're basically good to go - though you'll need to install git.

However if you'd like to use a nice GUI editor (such as Github's [Atom](https://atom.io/)) you have to beware. There's a blog post which is very explicit that you [*must not change Linux files from Windows*](https://blogs.msdn.microsoft.com/commandline/2016/11/17/do-not-change-linux-files-using-windows-apps-and-tools/). Instead we go the other way, and access the Windows filesystem from the shell. This lets us edit our files in an editor while in a Windows environment but then run our changes from our bash shell (which we just set up with Tensorflow).

The Windows filesystem is located under `/mnt/c` (or other drive letter), but if things are stored in your user directory then the paths can get a bit long. So first (this is optional) I like to add a shortcut to my working directory so it's easily accessible by adding the following to my `~/.profile` file:

```
export TFSCRATCH=/mnt/c/Users/Adam/SomeDirectory
```

You'll need to `source ~/.profile`, then you can just `cd $TFSCRATCH` whenever you want to get to your working directory.

If you're using Atom (like I am) there's a handy included extension called [Line Ending Selector](https://github.com/atom/line-ending-selector) - it allows you to specify which line endings you'd like to use. Swap it to `LF` when editing your Python files.

Now, running code is as you'd expect from a bash shell. Here I run the [basic MNIST sample from Google](https://github.com/tensorflow/tensorflow/blob/master/tensorflow/examples/tutorials/mnist/mnist_softmax.py):

```
adam@ADAM-PC:~$ cd $TFSCRATCH
adam@ADAM-PC:/mnt/c/Users/Adam/...$ python mnist_basic_google.py
Successfully downloaded train-images-idx3-ubyte.gz 9912422 bytes.
Extracting /tmp/tensorflow/mnist/input_data/train-images-idx3-ubyte.gz
Successfully downloaded train-labels-idx1-ubyte.gz 28881 bytes.
Extracting /tmp/tensorflow/mnist/input_data/train-labels-idx1-ubyte.gz
Successfully downloaded t10k-images-idx3-ubyte.gz 1648877 bytes.
Extracting /tmp/tensorflow/mnist/input_data/t10k-images-idx3-ubyte.gz
Successfully downloaded t10k-labels-idx1-ubyte.gz 4542 bytes.
Extracting /tmp/tensorflow/mnist/input_data/t10k-labels-idx1-ubyte.gz
0.9174
```

So; edit in Windows, run in bash. Easy.
