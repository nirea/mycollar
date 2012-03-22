Meet myCollar
=============

myCollar is an OpenCollar side project where I (nirea) and some other intrepid
devs are experimenting with some new architectural ideas that would take a lot
of work to wedge into the OpenCollar codebase.

The Problem
===========

If you've been following OC development for the last six months you've probably
seen a lot of angst over the number of drastic changes in the 3.7 release:

- Elimination of the web DB
- New updater/installer
- Some plugins being set to uninstalled by default
- Move from Google Code to Github

I'm proud of the work we did for 3.7.  It's made it a lot easier to get
involved in the collar's code.  But it pissed a lot of people off ("why doesn't
the collar do X anymore?!?!?!").  It was also slow, tedious work.  There is a
*lot* of code in there.

    nirea@computer:~/sl/ocupdater/lsl$ cat *lsl | wc -l
    23787

For those of you that don't speak Unix, that means there are nearly twenty-four
thousand lines of lsl code in OpenCollar. (Before 3.7, there were 24,555 lines
:( .)  

It's a lot of work to maintain all that.  Still, it gets worse:
- There are a lot of cross dependencies between the scripts.  Any work on the
  core scripts (auth, settings, listener, update) is quite likely to break
  things elsewhere.  
- Though SL is a *great* environment for experimenting and learning some
  programming, it is a hostile environment for maintaining a large codebase.
  There are no good tools for keeping inworld scripts in sync with a version
  control repository (git, mercurial, subversion, whatever).

When RL companies have this problem they hire a QA department.  When SL
projects have this problem they burn out release managers and slide into
stagnation.

The Solution
============

myCollar aims to make collar scripting fun again.  I have a few ideas how to do
that.  

1. Maintain a small core, and make everything pluggable.  You can see this in
   action if you look inside the new auth scripts and read the Pluggable Auth
   document.  We won't have a monolithic auth script that tries to define all
   scenarios in terms of owner/secowner/other.  myCollar's auth chain lets you add
   whatever auth logic you want.  If you want to give control to anyone whose name
   starts with a "J", it's easy to plug that in.
2. Share the load.  Unlike OC, which takes on responsibility for distributing a
   large number of plugins (e.g. badwords, bell, keyholder, etc), myCollar will
   come with just the basics.  If someone wants to add a feature, we'll help
   them write it as a plugin and distribute it under their name, but we're very
   unlikely to add it into the core.  That way the plugin author gets the
   glory, as well as the bug reports.
3. Share the load, part deux.  If we add a settings server, we'll make it so
   it's easy to run your own, on reasonably standard hosting.  Rather than the
   project maintaining a server for hundreds of thousands of people, it makes
   sense to me for communities to be able to maintain their own.
4. Don't require OC compatibility. Example: myCollar has a new, much-simplified
   menu system.  It's not compatible with the call-and-response system that OC
   uses.  That's OK.  Maybe someday someone updates all the plugins and
   backports myCollar's menu system to OC.  That would be awesome.  But I'm not
   volunteering to do that work.
5. Release a much smaller number of designs.  One of the really tedious things
   about releasing a new OC version is making sure all the collars in our back
   catalog have the new scripts inside.  myCollar will not maintain a big back
   catalog like this.  Other than the stock collar, designs will be released
   for a limited time only.
