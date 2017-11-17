bool Checked;
int currentSmx;

enum ePlugin
{
    pl_core,
    pl_AMP,
    pl_Store,
    pl_MCER,
    pl_Unknown
}

static char smxPath[ePlugin][128] =
{
    "addons/sourcemod/plugins/core.smx",
    "addons/sourcemod/plugins/advmusicplayer.smx",
    "addons/sourcemod/plugins/store.smx",
    "addons/sourcemod/plugins/mapchooser_extended.smx",
    "addons/sourcemod/plugins/"
};

static char smxDLPath[ePlugin][128] =
{
    "addons/sourcemod/data/download/core.smx",
    "addons/sourcemod/data/download/advmusicplayer.smx",
    "addons/sourcemod/data/download/store.smx",
    "addons/sourcemod/data/download/mapchooser_extended.smx",
    "addons/sourcemod/data/download/"
};

static char smxShort[ePlugin][16] =
{
    "core",
    "AMP",
    "Store",
    "MCER",
    "Unknown"
}

void SMX_OnAllPluginLoaded()
{
    RegAdminCmd("sm_updatesmx", Command_UpdateSmx, ADMFLAG_ROOT);
}

public Action Command_UpdateSmx(int client, int args)
{
    SMX_OnDatabaseAvailable(true);
    return Plugin_Handled;
}

void SMX_OnDatabaseAvailable(bool command = false)
{
    if(Checked && !command)
        return;
    
    Checked = true;
    
    char md5[33], url[192];
    ePlugin plugin = pl_Unknown;
    
    //check core
    plugin = pl_core;
    if(System2_GetFileMD5(smxPath[plugin], md5, 33))
    {
        currentSmx++;
        FormatEx(url, 192, "https://plugins.csgogamers.com/get.php?plugin=%s&md5=%s", smxShort[plugin], md5);
        System2_DownloadFile(SMX_OnDownloadSmxCompleted, url, smxDLPath[plugin], plugin);
    }
    
    //check amp
    plugin = pl_AMP;
    if(System2_GetFileMD5(smxPath[plugin], md5, 33))
    {
        currentSmx++;
        FormatEx(url, 192, "https://plugins.csgogamers.com/get.php?plugin=%s&md5=%s", smxShort[plugin], md5);
        System2_DownloadFile(SMX_OnDownloadSmxCompleted, url, smxDLPath[plugin], plugin);
    }

    CreateTimer(10.0, Timer_CheckSmxCompleted, _, TIMER_REPEAT);
}

public void SMX_OnDownloadSmxCompleted(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow, ePlugin plugin)
{
    if(finished)
    {
        if(!StrEqual(error, ""))
        {
            LogError("Download %s Error: %s ", smxDLPath[plugin], error);
        }
        else
        {
            // download return error
            if(FileSize(smxDLPath[plugin]) < 1024)
            {
                LogMessage("%s is up to date", smxPath[plugin]);
            }
            else
            {
                DeleteFile(smxPath[plugin]);
                RenameFile(smxPath[plugin], smxDLPath[plugin]);
                DeleteFile(smxDLPath[plugin]);
            }
        }
        currentSmx--;
    }
}

public Action Timer_CheckSmxCompleted(Handle timer)
{
    if(currentSmx > 0)
        return Plugin_Continue;
    
    LogMessage("All plugins are up to date, restarting server...");
    ServerCommand("exit");
    
    return Plugin_Stop;
}