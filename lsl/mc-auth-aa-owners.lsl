// This script is an auth plugin.  This particular auth plugin checks whether
// the command came from an owner or an object owned by an owner.

//MC MESSAGE MAP
integer DOMENU = -800;
integer MC_BTN_CLICK = -12000;
integer MC_AUTH_REQUEST = -13000;
integer MC_COMMAND = -14000;
integer MC_COMMAND_SAFEWORD = -14200;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
string UPMENU = "^";

// when we have to do a sensor to scan for potential nearby owners to add, remember the 
// key of the person using the dialog in this variable.
key sensor_rcpt;

// 2-strided list in form [ownerkey,ownername]
list owners;

string keyserver = "http://name2key.appspot.com/?name=";
key keyrequest;

RequestKey(string name) {
    keyrequest = llHTTPRequest(keyserver + llEscapeURL(name), [], "");
}

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

integer StartsWith(string str, string pattern) {
    return llSubStringIndex(str, pattern) == 0;
}

AddOwner(key id, string name) {
    integer idx = llListFindList(owners, [id]);
    if (idx == -1) {
        owners += [id, name];
    } else {
        // owner already present.  just update the name
        owners = llListReplaceList(owners, [name], idx + 1, idx + 1);
    }
    string msg = name + " is now an owner on " + llKey2Name(llGetOwner()) + "'s collar.";
    Notify(id, msg, TRUE);
}

RemOwner(key id, key user) {
    integer idx = llListFindList(owners, [id]);
    if (idx != -1) {
        string name = llList2String(owners, idx + 1);
        owners = llDeleteSubList(owners, idx, idx + 1);
        string msg = name + " is no longer an owner on " + llKey2Name(llGetOwner()) + "'s collar.";
        Notify(user, msg, TRUE);        
    }
}

Notify(key id, string msg, integer notify_wearer) {
    if (id == llGetOwner()) {
        llOwnerSay(msg);
    } else {
        llInstantMessage(id, msg);
        if (notify_wearer) {
            llOwnerSay(msg);
        }
    }
}

list owner_menus;
OwnerMenu(key av) {
    // show buttons for adding and removing owners.
    owner_menus += [Dialog(
        av, 
        "Choose an option",
        ["Add", "Remove", "Dump"],
        [UPMENU],
        0
    )];
}

string RandomID() {
    string chars = "0123456789abcdef";
    string emp;
    integer p;
    do {
        integer idx = (integer)llFrand(16);
        emp += llGetSubString(chars, idx, idx);
    } while(32 > ++p);                                                    
    return emp;
}

key Dialog(key rcpt, string prompt, list choices, list utility_buttons, integer page)
{
    key id = RandomID();
    llMessageLinked(LINK_SET, DIALOG, 
        (string)rcpt + "|" + 
        prompt + "|" +
        (string)page + "|" + 
        llDumpList2String(choices, "`") + "|" +
        llDumpList2String(utility_buttons, "`"), id);
    return id;
}

list DeleteFromList(list container, list items_to_remove) {
    integer idx = llListFindList(container, items_to_remove);
    if (idx == -1) {
        return container;
    }
    return llDeleteSubList(container, idx, llGetListLength(items_to_remove) - 1);
}

// a 2-strided list in form [key,name], where we store sensor results while showing a dialog based on them.
list sensor_results;

list sensor_menus;
SensorMenu(key av) {
    integer n;
    integer stop = llGetListLength(sensor_results);
    list names;
    for (n = 0; n < stop; n += 2) {
        names += llList2List(sensor_results, n + 1, n + 1);
    }
    sensor_menus += [Dialog(
        av,
        "Choose a person",
        names,
        [UPMENU],
        0
    )];
}

list remowner_menus;
RemOwnerMenu(key av) {
    integer n;
    integer stop = llGetListLength(owners);
    list names;
    for (n = 0; n < stop; n += 2) {
        names += llList2List(owners, n + 1, n + 1);
    }
    remowner_menus += [Dialog(
        av,
        "Choose a person",
        names,
        [UPMENU],
        0
    )];    
}

string OWNER_BUTTON = "btn_Authorize_Owners";
ParentMenu(key id, string child) {
    list parts = llParseString2List(child, ["_"], []);
    // build parent menu name by stripping off child
    string parent_btn = llDumpList2String(llList2List(parts, 0, -2), "_");
    llMessageLinked(LINK_SET, DOMENU, parent_btn, id);
}


default
{
    link_message(integer sender, integer num, string str, key id) {
        if (num == MC_AUTH_REQUEST + AUTH_INDEX) {
            
            // We've received an auth request on our dedicated channel.
            if (llListFindList(owners, [llGetOwnerKey(id)]) != -1) {
                // We just did something a little tricky.  By using
                // llGetOwnerKey, it may look like we're only checking objects
                // and not avatars.  But if you pass an av id to llGetOwnerKey,
                // it will actually give the same key right back.  So with that
                // one check, we handle both objects and avatars.
                // http://wiki.secondlife.com/wiki/LlGetOwnerKey

                // The command came from an owner.  Permission granted!
                llMessageLinked(LINK_SET, MC_COMMAND, str, id);
            } else if (llGetListLength(owners) != 0 && 
                       (StartsWith(str, "owner") || StartsWith(str, "remowner"))) {
                // we received an "owner" command but there is already at least one owner in the list, 
                // and this person isn't in it.  Drop the auth request and say sorry
                Notify(id, "Sorry, only owners may add/remove owners.", FALSE);
            } else {
                // That logic's a bit tricky.  Basically it only lets owners
                // add other owners, unless there aren't any owners set, in
                // which case the auth request will be forwarded on to other
                // auth scripts.  Commands that don't start with "owner" are
                // also forwarded.
                integer NEXT_AUTH_INDEX = MC_AUTH_REQUEST + AUTH_INDEX + 1;
                llMessageLinked(LINK_SET, NEXT_AUTH_INDEX, str, id);
            }
        } else if (num == MC_COMMAND) {
            if (StartsWith(str, "owner ")) {
                // someone's trying to set an owner with a chat command.
                list cmd_params = llDeleteSubList(llParseString2List(str, [" "], []), 0, 0);
                integer cmd_length = llGetListLength(cmd_params);
                if (cmd_length == 2) {
                    // assume we got first and last name.
                    string name = llDumpList2String(cmd_params, " ");

                    // if matches self, then add to list
                    string myname = llKey2Name(llGetOwner());
                    if (llToLower(name) == llToLower(myname)) {
                        AddOwner(llGetOwner(), myname);
                    } else {
                        // else make an http request to get the prospective owner's key.
                        RequestKey(name);
                    }
                } else if (cmd_length == 3) {
                    // assume we got first and last name, as well as a key
                    string name = llDumpList2String(llList2List(cmd_params, 0,
                                                                1), " ");
                    key new_owner = (key)llList2String(cmd_params, 2);
                    // TODO: check that new_owner is a valid key.
                    AddOwner(new_owner, name);
                }
            } else if (StartsWith(str, "remowner ")) {
                list cmd_params = llDeleteSubList(llParseString2List(str, [" "], []), 0, 0);
                integer cmd_length = llGetListLength(cmd_params);
                if (cmd_length == 2) {
                    // remove by name
                    integer n;
                    integer stop = llGetListLength(owners);
                    for (n = 0; n < stop; n += 2) {
                        string name = llToLower(llDumpList2String(llList2List(cmd_params, 0,
                                                                1), " "));
                        if (name == llToLower(llList2String(owners, n + 1))) {
                            RemOwner(llList2Key(owners, n), id);
                        }
                    }
                } else if (cmd_length == 3) {
                    // remove by key
                    key av = (key)llList2String(cmd_params, 2);
                    RemOwner(av, id);
                }
            }
        } else if (num == MC_BTN_CLICK) {
            if (str == OWNER_BUTTON) {
                OwnerMenu(id);
            }
        } else if (num == DIALOG_RESPONSE) {
            if (llListFindList(owner_menus, [id]) != -1) {
                // remove the dialog handle
                owner_menus = DeleteFromList(owner_menus, [id]);
                // parse the str parts
                list parts = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(parts, 0);
                string msg = llList2String(parts, 1);
                if (msg == "Add") {
                    // give a menu showing names of nearby avatars.
                    sensor_rcpt = av;
                    llSensor("","", AGENT, 20.0, PI);    
                } else if (msg == "Remove") {
                    RemOwnerMenu(av);
                } else if (msg == "Dump") {
                    // dump a list of all owners, suitable for pasting into a notecard
                    string out = "OWNERS:\n";
                    integer n;
                    integer stop = llGetListLength(owners);
                    for (n = 0; n < stop; n += 2) {
                        out += llDumpList2String(llList2List(owners, n, n + 1), ",") + "\n";
                    }
                    Notify(av, out, FALSE);
                    OwnerMenu(av);
                } else if (msg == UPMENU) {
                    ParentMenu(av, OWNER_BUTTON);
                }
            } else if (llListFindList(sensor_menus, [id]) != -1) {
                sensor_menus = DeleteFromList(sensor_menus, [id]);
                list parts = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(parts, 0);
                string msg = llList2String(parts, 1);
                // we got a name back.  Look up the key and send an 'owner' command through the system.
                integer idx = llListFindList(sensor_results, [msg]);
                if (idx != -1) {
                    string cmd = "owner " + msg + " " + llList2String(sensor_results, idx - 1);
                    llMessageLinked(LINK_SET, MC_AUTH_REQUEST, cmd, av);
                }
                
                OwnerMenu(av);
            } else if (llListFindList(remowner_menus, [id]) != -1) {
                remowner_menus = DeleteFromList(remowner_menus, [id]);
                list parts = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(parts, 0);
                string msg = llList2String(parts, 1);
                integer idx = llListFindList(owners, [msg]);
                if (idx != -1) {
                    string cmd = "remowner " + msg + " " + llList2String(owners, idx - 1);
                    llMessageLinked(LINK_SET, MC_AUTH_REQUEST, cmd, av);
                }
                
                OwnerMenu(av);                                 
            }
        } else if (num == DIALOG_TIMEOUT) {
            sensor_menus = DeleteFromList(sensor_menus, [id]);    
            owner_menus = DeleteFromList(owner_menus, [id]);                    
            remowner_menus = DeleteFromList(remowner_menus, [id]);              
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
        
    http_response(key id, integer status, list meta, string body) {
        if (id == keyrequest && status == 200) {
            list parts = llParseString2List(body, [":"], []);
            string name = llList2String(parts, 0);
            key av = (key)llList2String(parts, 1);
            AddOwner(av, name);
            // name2key will return an error response code if lookup fails:

            // curl -I http://name2key.appspot.com/?name=nirea%20residen
            // HTTP/1.1 405 Method Not Allowed
            // Content-Type: text/html; charset=utf-8
            // Cache-Control: no-cache
            // Expires: Fri, 01 Jan 1990 00:00:00 GMT
            // Date: Sun, 18 Mar 2012 04:54:33 GMT
            // Server: Google Frontend
            // Content-Length: 0

        }
    }
    
    sensor(integer num) {
        // build a list of keys and names of all avatars sensed.
        sensor_results = [];
        integer n;
        for (n = 0; n < num; n++) {
            if (llStringLength(llDetectedName(n)) <= 24) {
                sensor_results += [
                    llDetectedKey(n), llDetectedName(n)
                ];                
            } else {
                // TODO: Give a nice error message saying that this person must be added with a chat command.
            }
        }
        // Send a dialog with the names.
        SensorMenu(sensor_rcpt);
    }
    
    no_sensor() {
        Notify(sensor_rcpt, "Sensor found no avatars nearby.", FALSE);
        OwnerMenu(sensor_rcpt);
    }
}

