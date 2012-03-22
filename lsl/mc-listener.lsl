//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//listener

integer g_iListenChan = 1;
integer g_iListenChan0 = TRUE;
string g_sPrefix = ".";

// Channel for objects to send commands with low crosstalk because we customize 
// it per-av below.
integer g_iHUDChan = -1334245234;

integer g_iLockMeisterChan = -8888;

integer g_iListener1;
integer g_iListener2;
integer g_iLockMeisterListener;
integer g_iHUDListener;

//MC MESSAGE MAP
integer MC_BTN_CLICK = -12000;
integer MC_AUTH_REQUEST = -13000;
integer MC_COMMAND = -14000;
integer MC_COMMAND_SAFEWORD = -14200;

integer POPUP_HELP = 1001;

string g_sSafeWord = "SAFEWORD";

key g_kWearer;
string g_sSeparator = "|";
string g_iAuth;
string UUID;
string g_sCmd;

integer GetOwnerChannel(key kOwner, integer iOffset)
{
    integer iChan = (integer)("0x"+llGetSubString((string)kOwner,2,7)) + iOffset;
    if (iChan>0)
    {
        iChan=iChan*(-1);
    }
    if (iChan > -10000)
    {
        iChan -= 30000;
    }
    return iChan;
}

Debug(string sStr)
{
    //llOwnerSay(llGetScriptName() + " Debug: " + sStr);
}

SetListeners()
{
    llListenRemove(g_iListener1);
    llListenRemove(g_iListener2);
    llListenRemove(g_iLockMeisterListener);

    llListenRemove(g_iHUDListener);

    if(g_iListenChan0 == TRUE)
    {
        g_iListener1 = llListen(0, "", NULL_KEY, "");
    }

    g_iListener2 = llListen(g_iListenChan, "", NULL_KEY, "");
    g_iLockMeisterListener = llListen(g_iLockMeisterChan, "", NULL_KEY, (string)g_kWearer + "collar");

    g_iHUDListener = llListen(g_iHUDChan, "", NULL_KEY ,"");

}

string AutoPrefix()
{
    list sName = llParseString2List(llKey2Name(g_kWearer), [" "], []);
    return llToLower(llGetSubString(llList2String(sName, 0), 0, 0)) + llToLower(llGetSubString(llList2String(sName, 1), 0, 0));
}

string StringReplace(string sSrc, string sFrom, string sTo)
{//replaces all occurrences of 'sFrom' with 'sTo' in 'sSrc'.
    //Ilse: blame/applaud Strife Onizuka for this godawfully ugly though apparently optimized function
    integer iLen = (~-(llStringLength(sFrom)));
    if(~iLen)
    {
        string  sBuffer = sSrc;
        integer iBufPos = -1;
        integer iToLen = (~-(llStringLength(sTo)));
        @loop;//instead of a while loop, saves 5 bytes (and run faster).
        integer iToPos = ~llSubStringIndex(sBuffer, sFrom);
        if(iToPos)
        {
            iBufPos -= iToPos;
            sSrc = llInsertString(llDeleteSubString(sSrc, iBufPos, iBufPos + iLen), iBufPos, sTo);
            iBufPos += iToLen;
            sBuffer = llGetSubString(sSrc, (-~(iBufPos)), 0x8000);
            //sBuffer = llGetSubString(sSrc = llInsertString(llDeleteSubString(sSrc, iBufPos -= iToPos, iBufPos + iLen), iBufPos, sTo), (-~(iBufPos += iToLen)), 0x8000);
            jump loop;
        }
    }
    return sSrc;
}

integer StartsWith(string sHayStack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(sHayStack, llStringLength(sNeedle), -1) == sNeedle;
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) {
        llOwnerSay(sMsg);
    } else {
            llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer) {
            llOwnerSay(sMsg);
        }
    }
}

default
{
    state_entry()
    {
        g_kWearer = llGetOwner();
        g_sPrefix = AutoPrefix();

        g_iHUDChan = GetOwnerChannel(g_kWearer, 1111); // persoalized channel for this sub

        SetListeners();
    }
        
    touch_start(integer total_number) {
        llMessageLinked(LINK_SET, MC_AUTH_REQUEST, "menu", llDetectedKey(0));
    }

    listen(integer sChan, string sName, key kID, string sMsg)
    {
        // new object/HUD channel block
        if (sChan == g_iHUDChan)
        {
            //check for a ping, if we find one we request auth and answer in LMs with a pong
            if (sMsg==(string)g_kWearer + ":ping")
            {
                llMessageLinked(LINK_SET, MC_AUTH_REQUEST, "ping", llGetOwnerKey(kID));
            }
            // an object wants to know the version, we check if it is allowed to
            if (sMsg==(string)g_kWearer + ":version")
            {
                llMessageLinked(LINK_SET, MC_AUTH_REQUEST, "objectversion", llGetOwnerKey(kID));
            }
            // it it is not a ping, it should be a commad for use, to make sure it has to have the key in front of it
            else if (StartsWith(sMsg, (string)g_kWearer + ":"))
            {
                sMsg = llGetSubString(sMsg, 37, -1);
                llMessageLinked(LINK_SET, MC_AUTH_REQUEST, sMsg, kID);
            }
            else
            {
                llMessageLinked(LINK_SET, MC_AUTH_REQUEST, sMsg, llGetOwnerKey(kID));
            }
        }

        else if (sChan == g_iLockMeisterChan)
        {
            llWhisper(g_iLockMeisterChan,(string)g_kWearer + "collar ok");
        }
        else if((kID == g_kWearer) && ((sMsg == g_sSafeWord)||(sMsg == "(("+g_sSafeWord+"))")))
        { // safeword can be the safeword or safeword said in OOC chat "((SAFEWORD))"
            llMessageLinked(LINK_SET, MC_COMMAND_SAFEWORD, "", NULL_KEY);
            llOwnerSay("You used your safeword, your owner will be notified you did.");
        }
        else
        { //check for our prefix, or *
            if (StartsWith(sMsg, g_sPrefix))
            {
                //trim
                sMsg = llGetSubString(sMsg, llStringLength(g_sPrefix), -1);
                llMessageLinked(LINK_SET, MC_AUTH_REQUEST, sMsg, kID);
            }
            else if (llGetSubString(sMsg, 0, 0) == "*")
            {
                sMsg = llGetSubString(sMsg, 1, -1);
                llMessageLinked(LINK_SET, MC_AUTH_REQUEST, sMsg, kID);
            }
            // added # as prefix for all subs around BUT yourself
            else if ((llGetSubString(sMsg, 0, 0) == "#") && (kID != g_kWearer))
            {
                sMsg = llGetSubString(sMsg, 1, -1);
                llMessageLinked(LINK_SET, MC_AUTH_REQUEST, sMsg, kID);
            }
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {

        if (iNum == MC_COMMAND)
        {
            list lParams = llParseString2List(sStr, [" "], []);
            string sCommand = llToLower(llList2String(lParams, 0));
            string sValue = llToLower(llList2String(lParams, 1));
            if (sStr == "settings")
                // answer for settings command
            {
                Notify(kID,"prefix: " + g_sPrefix, FALSE);
                Notify(kID,"channel: " + (string)g_iListenChan, FALSE);
            }
            else if (sStr == "ping")
                // ping from an object, we answer to it on the object channel
            {
                llSay(GetOwnerChannel(kID,1111),(string)g_kWearer+":pong");
            }
            //handle changing prefix and channel from owner
            else if (sCommand == "prefix")
            {
                string sNewPrefix = llList2String(lParams, 1);
                if (sNewPrefix == "auto")
                {
                    g_sPrefix = AutoPrefix();
                }
                else if (sNewPrefix != "")
                {
                    g_sPrefix = sNewPrefix;
                }
                SetListeners();
                Notify(kID, "\n" + llKey2Name(g_kWearer) + "'s prefix is '" + g_sPrefix + "'.\nTouch the collar or say '" + g_sPrefix + "menu' for the main menu.\nSay '" + g_sPrefix + "help' for a list of chat commands.", FALSE);
            }
            else if (sCommand == "channel")
            {
                integer iNewChan = (integer)llList2String(lParams, 1);
                if (iNewChan > 0)
                {
                    g_iListenChan =  iNewChan;
                    SetListeners();
                    Notify(kID, "Now listening on channel " + (string)g_iListenChan + ".", FALSE);
                }
                else if (iNewChan == 0)
                {
                    g_iListenChan0 = TRUE;
                    SetListeners();
                    Notify(kID, "You enabled the public channel listener.\nTo disable it use -1 as channel command.", FALSE);
                }
                else if (iNewChan == -1)
                {
                    g_iListenChan0 = FALSE;
                    SetListeners();
                    Notify(kID, "You disabled the public channel listener.\nTo enable it use 0 as channel command, remember you have to do this on your channel /" +(string)g_iListenChan, FALSE);
                }
                else
                {  //they left the param blank
                    Notify(kID, "Error: 'channel' must be given a number.", FALSE);
                }
            }
            if (kID == g_kWearer)
            {
                if (sCommand == "safeword")
                {   // new for safeword
                    if(llStringTrim(sValue, STRING_TRIM) != "")
                    {
                        g_sSafeWord = llList2String(lParams, 1);
                        llOwnerSay("You set a new safeword: " + g_sSafeWord + ".");
                    }
                    else
                    {
                        llOwnerSay("Your safeword is: " + g_sSafeWord + ".");
                    }
                }
                else if (sStr == g_sSafeWord)
                { //safeword used with prefix
                    llMessageLinked(LINK_SET, MC_COMMAND_SAFEWORD, "", NULL_KEY);
                    llOwnerSay("You used your safeword, your owner will be notified you did.");
                }
            }
        }
        else if (iNum == POPUP_HELP)
        {
            //replace _PREFIX_ with prefix, and _CHANNEL_ with (strin) channel
            sStr = StringReplace(sStr, "_PREFIX_", g_sPrefix);
            sStr = StringReplace(sStr, "_CHANNEL_", (string)g_iListenChan);
            Notify(kID, sStr, FALSE);
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }
}

