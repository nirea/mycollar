Intro
=====

Unlike previous collar systems, MyCollar does not impose a hardcoded scheme for determining who is authorized to control the collar.  Instead, MyCollar allows for pluggable authentication scripts.  In order for this to work, all authentication scripts must follow this spec:

myCollar Auth Plugin Spec
=========================

1. All auth scripts will have names that begin with "mc-auth".
2. At startup, a valid auth script will check the prim's inventory for all
   scripts whose names begin with "mc-auth".  It will check where it itself sits
   in the list, and store that position in a global AUTH_INDEX integer.  This
   number should be recomputed whenever prim inventory changes.
3. Whenever a new command is received by the listener, it will send a link
   message on the AUTH_REQUEST channel, with the command text in the string field,
   and the command giver's key in the uuid field.
4. Each auth script will respond only to auth request link messages where the
   message's number field equals AUTH_REQUEST + AUTH_INDEX.  (So only the first
   auth script will respond to bare AUTH_REQUEST messages, since its AUTH_INDEX
   will be zero.)  The script will then use whatever internal logic it wants in
   order to determine whether the given UUID is authorized to perform the given
   action.  This may include querying a database, or doing a sensor for proximity
   of some person or object, or anything that a script can do.  After making this
   determination, the auth script must do one of three things:
    - If access is granted, then the script should send a COMMAND message to be picked up by the plugin that will actually perform the command.
    - If access is absolutely denied (like with a blacklist script), then the auth script may silently drop the message, taking no further action.
    - If the auth script has no rules on whether the given person should be given access or not, then it should forward the request on to the next auth script by sending it on the channel AUTH_REQUEST + AUTH_INDEX + 1.  If there are no more scripts in the auth chain, then access will fail.

In most cases, it is better to forward the request than drop it, because dropping requests prevents your plugin from playing nicely with other auth scripts that may be present.  As long as auth scripts forward requests, users will be able to compose a huge variety of auth behaviors by picking the auth plugins they want to have installed.  

Example
=======

Suppose a collar had these auth scripts in it:

1. mc-auth-00-owner
2. mc-auth-10-blacklist
3. mc-auth-20-some-gorean-sim

The listener hears a "nadu" command.  It will use the AUTH_REQUEST channel to send a message to the 'mc-auth-00-owner' script (the first one in the list), which will check whether the sender is in the list of owners.  If so, then it will send a COMMAND message with the string "nadu" and the key of the person who sent the command.  The anim script will pick this up and play the anim.

But if the person isn't in the owner list, the owner auth script will use the AUTH_REQUEST + 1 channel to forward the request on to the next auth plugin, which is mc-auth-10-blacklist.

The blacklist script will check whether the command sender is in a list of blacklisted av keys.  (Or if the command was sent by an object, whether the object's owner is blacklisted.)  If the sender is blacklisted, the blacklist script will do nothing more.  The command is dropped.

If the sender is not blacklisted, then the blacklist script will use the AUTH_REQUEST + 2 channel to forward the request on to the next auth plugin, which is mc-auth-20-some-gorean-sim.

Suppose the Gor sim script is a plugin from a Gorean estate that has very specific rules about how someone can capture someone else.  Suppose their battle meter, for example, records captures in an online database and sets timeouts for them.  This auth plugin could query that web database to determine whether the command sender has performed the actions necessary to have captured the collar wearer.  If so, the script would send the COMMAND message.  If not, then the script would forward the request on to AUTH_REQUEST + 3.  

Since there is no auth plugin listening on AUTH_REQUEST + 3, the chain would end here.

