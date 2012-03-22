integer heightfix_enabled = TRUE;
string HEIGHTFIX = "HeightFix";
string TICKED = "(*)";
string UNTICKED = "( )";
string UPMENU = "^";
string MORE = ">";

// TODO: Derive these labels from the button names instead of duplicating them here.

string RELEASE = "*Release*";
string POSEPREFIX = "pose-";
string POSE_BUTTON = "btn_Animate_Pose";
string SETTINGS_BUTTON = "btn_Animate_Settings";
list dialog_ids;//three strided list of avkey, dialogid, and menuname
integer DIALOG_STRIDE = 3;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;


// remember the last anim played so we can stop it.
string last_anim;

//MC MESSAGE MAP
integer DOMENU = -800;
integer MC_BTN_CLICK = -12000;
integer MC_AUTH_REQUEST = -13000;
integer MC_COMMAND = -14000;
integer MC_COMMAND_OBJECT = -14100;
integer MC_COMMAND_SAFEWORD = -14200;

//for the height scaling feature
key card_line_id;
string card = "~heightscalars";
integer card_line = 0;
list anim_scalars;//a 3-strided list in form animname,scalar,delay
integer height_adjustment = 0;

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

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page) {
    key id = RandomID();
    llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), id);
    return id;
}
        
ParentMenu(key id, string child) {
    list parts = llParseString2List(child, ["_"], []);
    // build parent menu name by stripping off child
    string parent_btn = llDumpList2String(llList2List(parts, 0, -2), "_");
    llMessageLinked(LINK_SET, DOMENU, parent_btn, id);
}

PoseMenu(key id, integer page)
{ //create a list
    string sPrompt = "Choose an anim to play.";
    key menuid = Dialog(id, sPrompt, GetAnimList(), [RELEASE, UPMENU], page);
    list newstride = [id, menuid, POSE_BUTTON];
    integer idx = llListFindList(dialog_ids, [id]);
    if (idx == -1)
    {
        dialog_ids += newstride;
    }
    else
    {//this person is already in the dialog list.  replace their entry
        dialog_ids = llListReplaceList(dialog_ids, newstride, idx, idx - 1 + DIALOG_STRIDE);
    }
}

list GetAnimList()
{
    list poses=[];
    integer max = llGetInventoryNumber(INVENTORY_ANIMATION);
    integer i;
    integer preflength = llStringLength(POSEPREFIX);    
    for (i=0;i<max;i++)
    {
        string name=llGetInventoryName(INVENTORY_ANIMATION, i);
        // only include anims with our prefix
        if (llSubStringIndex(name, POSEPREFIX) == 0) {
            name = llDeleteSubString(name, 0, preflength - 1);
            // Silently hide animations with names over 24 chars.
            if (llStringLength(name) <= 24 && name != "")
            {
                poses+=[name];
            }        
        }
    }
    return poses;
}

SettingsMenu(key id)
{
    string prompt = "Choose an option.\n";
    list buttons;
    if(heightfix_enabled)
    {
        prompt += "\nThe height of some poses will be adjusted now.";
        buttons += [TICKED + HEIGHTFIX];
    }
    else
    {
        prompt += "\nThe height of the poses will not be changed.";
        buttons += [UNTICKED + HEIGHTFIX];
    }
    key menuid = Dialog(id, prompt, buttons, [UPMENU], 0);
    list newstride = [id, menuid, SETTINGS_BUTTON];
    integer idx = llListFindList(dialog_ids, [id]);
    if (idx == -1)
    {
        dialog_ids += newstride;
    }
    else
    {//this person is already in the dialog list.  replace their entry
        dialog_ids = llListReplaceList(dialog_ids, newstride, idx, idx - 1 + DIALOG_STRIDE);
    }
}
    
integer IsAnim(string item) {
    return llGetInventoryType(item) == INVENTORY_ANIMATION;
}
    
PlayAnim(string anim) {
    if (IsAnim(anim) && (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)) {
        // first stop the old one
        StopAnim(last_anim);
        llStartAnimation(anim);
        last_anim = anim;

        if (heightfix_enabled)
        {
            //adjust height for anims in anim_scalars
            integer iIndex = llListFindList(anim_scalars, [anim]);
            if (iIndex != -1)
            {//we just started playing an anim in our height_adjustment list
                //pause to give certain anims time to ease in
                llSleep((float)llList2String(anim_scalars, iIndex + 2));
                vector vAvScale = llGetAgentSize(llGetOwner());
                float fScalar = (float)llList2String(anim_scalars, iIndex + 1);
                height_adjustment = llRound(vAvScale.z * fScalar);
                if (height_adjustment > -30)
                {
                    height_adjustment = -30;
                }
                else if (height_adjustment < -50)
                {
                    height_adjustment = -50;
                }
                llStartAnimation("~" + (string)height_adjustment);
            }
        }    
    }
}

StopAnim(string anim) {
    if (IsAnim(anim) && (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)) {
        llStopAnimation(anim);
    }

    //stop any currently-playing height adjustment
    if (height_adjustment)
    {
        llStopAnimation("~" + (string)height_adjustment);
        height_adjustment = 0;
    }
}
        
default {
    link_message(integer sender, integer num, string str, key id) {
        if (num == MC_BTN_CLICK) {
            if (str == POSE_BUTTON) {
                PoseMenu(id, 0);
            } else if (str == SETTINGS_BUTTON) {
                SettingsMenu(id);
            }
        } else if (num == DIALOG_RESPONSE) {
            integer idx = llListFindList(dialog_ids, [id]);
            if (idx != -1) {
                //got a menu response meant for us.  pull out values
                list menu_params = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(menu_params, 0);
                string msg = llList2String(menu_params, 1);
                integer page = (integer)llList2String(menu_params, 2);
                string menutype = llList2String(dialog_ids, idx + 1);
                // Remove entry from dialog bookkeeping
                dialog_ids = llDeleteSubList(dialog_ids, idx - 1, idx - 2 +
                    DIALOG_STRIDE);

                if (menutype == POSE_BUTTON) {
                    if (msg == RELEASE) {
                        StopAnim(last_anim);
                        PoseMenu(av, page);                
                    } else if (msg == UPMENU) {
                        ParentMenu(av, POSE_BUTTON);
                    } else {
                        // If 'message' is one of our anims, play it.
                        PlayAnim(POSEPREFIX+msg);
                        PoseMenu(av, page);                        
                    }
                } else if (menutype == SETTINGS_BUTTON) {
                    if (msg == TICKED + HEIGHTFIX) {
                        // button was checked, so now disable heightfix
                        heightfix_enabled = FALSE;
                        SettingsMenu(av);                        
                    } else if (msg == UNTICKED + HEIGHTFIX) {
                        heightfix_enabled = TRUE;
                        SettingsMenu(av);                    
                    } else if (msg == UPMENU) {
                        ParentMenu(av, SETTINGS_BUTTON);
                    }
                }
            }
        }
    }

    state_entry() {
        if (llGetAttached()) {
            llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
        }
        //start reading the ~heightscalars notecard
        card_line_id = llGetNotecardLine(card, card_line);            
    }

    on_rez(integer num) {
        llResetScript();
    }
        
    dataserver(key id, string data)
    {
        if (id == card_line_id)
        {
            if (data != EOF)
            {
                anim_scalars += llParseString2List(data, ["|"], []);
                card_line++;
                card_line_id = llGetNotecardLine(card, card_line);
            }
        }
    }    
}

