list menus;//strided list in form [underscore-delimited menupath,pipe-delimited items in that menu]

string btnprefix = "btn";
string btnsep = "_";

list dialogids;//3-strided list of dialog ids, the avs they belong to, and the menu path.
integer stride = 3;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

integer MC_BTN_CLICK = -12000;
integer MC_AUTH_REQUEST = -13000;
integer MC_COMMAND = -14000;

integer DOMENU = -800;

string UPMENU = "^";

string ROOTMENU = "btn";

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


key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    key kID = RandomID();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}

DoMenu(key toucher, string path, integer page) {
    //get list of buttons from menus list
    //give dialog to toucher
    integer index = llListFindList(menus, [path]);
    if (index != -1) {
        list buttons = llParseStringKeepNulls(llList2String(menus, index + 1), ["|"], []);
    
        list utility;
        
        //add back button if we're in anything other than root menu
        if (path != ROOTMENU) {
            utility += [UPMENU];
        }
        
        key id = Dialog(toucher, "Pick an option.", buttons, utility, page);    
        
        //record dialog id, av, path
        list addme = [id, toucher, path];
        
        //we don't support simultaneous menus from the same person.  so if they're av key is in here, replace the entry
        integer index = llListFindList(dialogids, [toucher]);
        if (index == -1) {
            dialogids += addme;
        }
        else {
            //he's already using the menu, replace his dialog id
            dialogids = llListReplaceList(dialogids, addme, index - 1, index + 2);        
        }        
    }
    else {
        debug("error: path '" + path + "' not present in list");
    }
}

BuildMenuNode(list path) {
    string last = llList2String(path, -1);
    string parentpath = llDumpList2String([ROOTMENU] + llDeleteSubList(path, -1, -1), btnsep);
    
    // if parentpath is in "menus" list, then just add this child else add
    // parentpath and child to menus list
    integer index = llListFindList(menus, [parentpath]);
    if (index != -1 && !(index % 2)) {
        // parentpath found in menus list, in path part of the stride.  add
        // this child to the existing one(s)
        list children = llParseStringKeepNulls(llList2String(menus, index + 1), ["|"], []);
        //it should already be impossible to add duplicates but let's make sure
        if (llListFindList(children, [last]) == -1) {
            children += [last];
            menus = llListReplaceList(menus, [llDumpList2String(children, "|")], index + 1, index + 1);
        }
    }
    else {
        // parentpath was not found in menus list in path part of the stride.
        // add both parentpath and child in one swoop
        menus += [parentpath, last];
    }
}

BuildMenuPath(list path) {
    // Given a list like ["Main", "Animate", "Pose"] that represents a parent
    // menu, child, grandchild, etc, make sure that there's an entry in the
    // global menu for each level.
    while(llGetListLength(path)) {
        BuildMenuNode(path);
        // By popping off the end of the list, we ensure that parent menus are
        // built by calling BuildMenuNode for all of these:
            // ["Main", "Animate", "Pose"]
            // ["Main", "Animate"]
            // ["Main"]
        path = llDeleteSubList(path, -1, -1);
    }
}

BuildMenus() {
    menus = [];
    integer n;
    integer stop = llGetInventoryNumber(INVENTORY_NOTECARD);
    for (n = 0; n < stop; n++) {
        string name = llGetInventoryName(INVENTORY_NOTECARD, n);
        list path = llParseStringKeepNulls(name, [btnsep], []);
        string prefix = llList2String(path, 0);
        if (llSubStringIndex(prefix, btnprefix) == 0) {
            BuildMenuPath(llDeleteSubList(path, 0, 0));            
        }
    }    
}

debug(string str) {
    //llOwnerSay(llGetScriptName() + ": " + str);
}

default {
    state_entry() {
        BuildMenus();        
        debug("menus:\n" + llDumpList2String(menus, "\n"));        
    }
    
    link_message(integer sender, integer num, string str, key id) {
        //debug((string)num + ", " + str + ", " + (string)id);        
        //debug("linkmsg, dialogids: " + llDumpList2String(dialogids, ", "));
        
        if (num == DIALOG_RESPONSE) {
            debug("dialog response: " + str);
            //distinguish between main menu and submenus
            integer index = llListFindList(dialogids, [id]);      
            if (index != -1) {
                list params = llParseString2List(str, ["|"], []);
                integer page = (integer)llList2String(params, 0);
                string selection = llList2String(params, 1);
                
                key toucher = llList2Key(dialogids, index + 1);              
                string path = llList2String(dialogids, index + 2);
                
                debug("dialog path: " + path);
                //remove this dialog id
                dialogids = llDeleteSubList(dialogids, index, index + stride - 1);
                
                //return menus always                
                if (selection == UPMENU) {
                    //give the parent menu
                    list pathparts = llParseString2List(path, [btnsep], []);
                    pathparts = llDeleteSubList(pathparts, -1, -1);
                    
                    if (llGetListLength(pathparts)) {
                        DoMenu(toucher, llDumpList2String(pathparts, btnsep), 0);
                    }
                    else {
                        DoMenu(toucher, ROOTMENU, 0);
                    }
                }
                else if (~llListFindList(menus, [path + btnsep + selection])) {
                    //there's a menu for the selection.
                    DoMenu(toucher, path + btnsep + selection, 0);
                }

                list pathlist = llDeleteSubList(llParseStringKeepNulls(path, [btnsep], []), 0, 0);
                
                //if there's a BTN card, read it and send its messages         
                string btnname = llDumpList2String([btnprefix] + pathlist + [selection], btnsep);
                if (llGetInventoryType(btnname) == INVENTORY_NOTECARD) {
                    llMessageLinked(LINK_SET, MC_BTN_CLICK, btnname, toucher);
                }
            }            
        }         
        else if (num == DIALOG_TIMEOUT) {
            integer index = llListFindList(dialogids, [id]);
            if (index != -1) {
                dialogids = llDeleteSubList(dialogids, index, index + stride - 1);
            }                
        }      
        else if (num == DOMENU) {
            if (str) {
                DoMenu(id, str, 0);
            }
            else {
                DoMenu(id, ROOTMENU, 0);                
            }
        } else if (num == MC_COMMAND && str == "menu") {
            DoMenu(id, ROOTMENU, 0);
        }
    }
    
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            BuildMenus();           
        }
        
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}

