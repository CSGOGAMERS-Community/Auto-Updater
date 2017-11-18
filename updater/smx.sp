bool Checked;
bool Success;
int currentSmx;

enum ePlugin
{
    pl_core,
    pl_AMP,
    pl_Store,
    pl_Updater,
    pl_MCR_mcr,
    pl_MCR_rtv,
    pl_MCR_nmt,
    pl_MCR_ext,
    pl_Unknown
}

static char smxPath[ePlugin][128] =
{
    "addons/sourcemod/plugins/core.smx",
    "addons/sourcemod/plugins/advmusicplayer.smx",
    "addons/sourcemod/plugins/store.smx",
    "addons/sourcemod/plugins/autoupdater.smx",
    "addons/sourcemod/plugins/mapchooser_redux.smx",
    "addons/sourcemod/plugins/rockthevote_redux.smx",
    "addons/sourcemod/plugins/nominations_redux.smx",
    "addons/sourcemod/plugins/maptimelimit_redux.smx",
    "addons/sourcemod/plugins/"
};

static char smxDLPath[ePlugin][128] =
{
    "addons/sourcemod/data/download/core.smx",
    "addons/sourcemod/data/download/advmusicplayer.smx",
    "addons/sourcemod/data/download/store.smx",
    "addons/sourcemod/data/download/autoupdater.smx",
    "addons/sourcemod/data/download/mapchooser_redux.smx",
    "addons/sourcemod/data/download/rockthevote_redux.smx",
    "addons/sourcemod/data/download/nominations_redux.smx",
    "addons/sourcemod/data/download/maptimelimit_redux.smx",
    "addons/sourcemod/data/download/"
};

static char smxShort[ePlugin][16] =
{
    "Core",
    "AMP",
    "Store",
    "Updater",
    "MCR",
    "MCR",
    "MCR",
    "MCR",
    "Unknown"
};

static char smxFile[ePlugin][32] =
{
    "core.smx",
    "advmusicplayer.smx",
    "store.smx",
    "autoupdater.smx",
    "mapchooser_redux.smx",
    "rockthevote_redux.smx",
    "nominations_redux.smx",
    "maptimelimit_redux.smx",
    ""
};

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
    
    //check
    for(int index = 0; index < view_as<int>(ePlugin); ++index)
    {
        plugin = view_as<ePlugin>(index);
        if(System2_GetFileMD5(smxPath[plugin], md5, 33))
        {
            currentSmx++;
            FormatEx(url, 192, "https://plugins.csgogamers.com/get.php?plugin=%s&md5=%s&file=%s", smxShort[plugin], md5, smxFile[plugin]);
            LogMessage("Update -> %s", url);
            System2_DownloadFile(SMX_OnDownloadSmxCompleted, url, smxDLPath[plugin], plugin);
        }
    }

    if(plugin != pl_Unknown)
        CreateTimer(60.0, Timer_CheckSmxCompleted, TIMER_REPEAT);
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
                LogMessage("%s is up to date -> %d", smxPath[plugin], FileSize(smxDLPath[plugin]));
            }
            else
            {
                Success = true;
                DeleteFile(smxPath[plugin]);
                RenameFile(smxPath[plugin], smxDLPath[plugin]);
                LogMessage("%s update successful -> size: %d", smxPath[plugin], FileSize(smxPath[plugin]));
            }
            DeleteFile(smxDLPath[plugin]);
        }
        currentSmx--;
    }
}

public Action Timer_CheckSmxCompleted(Handle timer)
{
    if(currentSmx > 0)
        return Plugin_Continue;
    
    if(!Success)
        return Plugin_Stop;

    LogMessage("All plugins are up to date, restarting server...");
    ServerCommand("exit");
    
    return Plugin_Stop;
}