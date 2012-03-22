// This script is an auth plugin.  This particular auth plugin checks whether
// the command came from the collar wearer or an object owned by the collar
// wearer.  If so, then the command is sent.  If not, then the command is
// forwarded on to the next auth plugin.

//MC MESSAGE MAP
integer MC_BTN_CLICK = -12000;
integer MC_AUTH_REQUEST = -13000;
integer MC_COMMAND = -14000;
integer MC_COMMAND_OBJECT = -14100;
integer MC_COMMAND_SAFEWORD = -14200;

integer AUTH_INDEX;

integer GetAuthIndex() {
    // loop over scripts in inventory to determine where I fall in the order 
    // of auth scripts.  This is alphabetical.
    integer n;
    integer stop = llGetInventoryNumber(INVENTORY_SCRIPT);
    integer idx = 0;
    string myname = llGetScriptName();
    for (n = 0; n < stop; n++) {
        string name = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (llSubStringIndex(name, "mc-auth") == 0) {
            if (name == myname) {
                return idx;
            }
            idx++;
        }
    }
    // If I never find myself then my name must not start with "mc-auth".
    // By setting a negative auth index, i'll be removed from the auth chain.
    return -1;
}


default
{
    link_message(integer sender, integer num, string str, key id) {
        if (num == MC_AUTH_REQUEST + AUTH_INDEX) {
            // We've received an auth request on our dedicated channel.
            if (llGetOwnerKey(id) == llGetOwner()) {
                // We just did something a little tricky.  By using
                // llGetOwnerKey, it may look like we're only checking objects
                // and not avatars.  But if you pass an av id to llGetOwnerKey,
                // it will actually give the same key right back.  So with that
                // one check, we handle both objects and avatars.
                // http://wiki.secondlife.com/wiki/LlGetOwnerKey

                // The command came from the wearer.  Permission granted!
                llMessageLinked(LINK_SET, MC_COMMAND, str, id);
            } else {
                // The command came from someone else.  Forward the auth
                // request to the next auth plugin.
                integer NEXT_AUTH_INDEX = MC_AUTH_REQUEST + AUTH_INDEX + 1;
                llMessageLinked(LINK_SET, NEXT_AUTH_INDEX, str, id);
            }
        }
    }

    state_entry() {
        AUTH_INDEX = GetAuthIndex();
    }

    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            AUTH_INDEX = GetAuthIndex();
        }
    }
}

