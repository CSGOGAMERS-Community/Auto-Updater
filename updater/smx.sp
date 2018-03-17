bool Checking;
int currentSmx;
ArrayList successList;

enum ePlugin
{
    pl_Core_main,
    pl_Core_users,
    pl_Core_stats,
    pl_Core_motd,
    pl_Core_vars,
    pl_Shop_core,
    pl_Shop_skin,
    pl_Shop_chat,
    pl_AMP,
    pl_Updater,
    pl_MCR_mcr,
    pl_MCR_rtv,
    pl_MCR_nmt,
    pl_MCR_ext,
    pl_MG_Core,
    pl_MG_CP
}

static char smxPath[ePlugin][128] =
{
    "addons/sourcemod/plugins/MagicGirl.smx",
    "addons/sourcemod/plugins/mg-user.smx",
    "addons/sourcemod/plugins/mg-stats.smx",
    "addons/sourcemod/plugins/mg-motd.smx",
    "addons/sourcemod/plugins/mg-vars.smx",
    "addons/sourcemod/plugins/shop-core.smx",
    "addons/sourcemod/plugins/shop-skin.smx",
    "addons/sourcemod/plugins/shop-chat.smx",
    "addons/sourcemod/plugins/advmusicplayer.smx",
    "addons/sourcemod/plugins/autoupdater.smx",
    "addons/sourcemod/plugins/mapchooser_redux.smx",
    "addons/sourcemod/plugins/rockthevote_redux.smx",
    "addons/sourcemod/plugins/nominations_redux.smx",
    "addons/sourcemod/plugins/maptimelimit_redux.smx",
    "addons/sourcemod/plugins/MiniGames.smx",
    "addons/sourcemod/plugins/cheater-punisher.smx"
};

static char smxDLPath[ePlugin][128] =
{
    "addons/sourcemod/data/download/MagicGirl.smx",
    "addons/sourcemod/data/download/mg-user.smx",
    "addons/sourcemod/data/download/mg-stats.smx",
    "addons/sourcemod/data/download/mg-motd.smx",
    "addons/sourcemod/data/download/mg-vars.smx",
    "addons/sourcemod/data/download/shop-core.smx",
    "addons/sourcemod/data/download/shop-skin.smx",
    "addons/sourcemod/data/download/shop-chat.smx",
    "addons/sourcemod/data/download/advmusicplayer.smx",
    "addons/sourcemod/data/download/autoupdater.smx",
    "addons/sourcemod/data/download/mapchooser_redux.smx",
    "addons/sourcemod/data/download/rockthevote_redux.smx",
    "addons/sourcemod/data/download/nominations_redux.smx",
    "addons/sourcemod/data/download/maptimelimit_redux.smx",
    "addons/sourcemod/data/download/MiniGames.smx",
    "addons/sourcemod/data/download/cheater-punisher.smx"
};

static char smxShort[ePlugin][32] =
{
    "MagicGirl - Core",
    "MagicGirl - User Manager",
    "MagicGirl - Stats",
    "MagicGirl - Motd",
    "MagicGirl - Vars Library",
    "Shop - Core",
    "Shop - Player Skin",
    "Shop - Chat Processor",
    "Advanced Music Player",
    "Auto Updater",
    "Mapchooser Redux",
    "Rock the Vote Redux",
    "Nominations Redux",
    "Maptime Extend Redux",
    "MiniGames - Core",
    "MiniGames - Cheater Punisher"
};

static char smxFile[ePlugin][32] =
{
    "MagicGirl.smx",
    "mg-user.smx",
    "mg-stats.smx",
    "mg-motd.smx",
    "mg-vars.smx",
    "shop-core.smx",
    "shop-skin.smx",
    "shop-chat.smx",
    "advmusicplayer.smx",
    "autoupdater.smx",
    "mapchooser_redux.smx",
    "rockthevote_redux.smx",
    "nominations_redux.smx",
    "maptimelimit_redux.smx",
    "MiniGames.smx",
    "cheater-punisher.smx"
};

static int smxId[ePlugin] = 
{
    101,
    102,
    103,
    104,
    105,
    201,
    202,
    203,
    401,
    402,
    301,
    302,
    303,
    304,
    501,
    502
};

void SMX_OnAllPluginLoaded()
{
    RegAdminCmd("sm_updatesmx", Command_UpdateSmx, ADMFLAG_ROOT);
    
    successList = new ArrayList();
    
    CreateTimer(7200.0, Timer_UpdatePlugin, _, TIMER_REPEAT);
}

public Action Timer_UpdatePlugin(Handle timer)
{
    SMX_OnDatabaseAvailable();
    return Plugin_Handled;
}

public Action Command_UpdateSmx(int client, int args)
{
    SMX_OnDatabaseAvailable();
    return Plugin_Handled;
}

void SMX_OnDatabaseAvailable()
{
    if(Checking)
        return;

    Checking = true;
    successList.Clear();

    char md5[33], url[192];
    ePlugin plugin;

    //check
    for(int index = 0; index < view_as<int>(ePlugin); ++index)
    {
        plugin = view_as<ePlugin>(index);
        if(System2_GetFileMD5(smxPath[plugin], md5, 33))
        {
            currentSmx++;

            FormatEx(url, 192, "https://plugins.csgogamers.com/get.php?plugin=%d&md5=%s&file=%s", smxId[plugin], md5, smxFile[plugin]);
            PrintToServer("Update -> %s", url);
            System2_DownloadFile(SMX_OnDownloadSmxCompleted, url, smxDLPath[plugin], plugin);
        }
        else if(FileExists(smxPath[plugin]))
            LogMessageEx("Get [%s] MD5 failed!", smxPath[plugin]);
    }

    if(currentSmx > 0)
        CreateTimer(60.0, Timer_CheckSmxCompleted, _, TIMER_REPEAT);
}

public void SMX_OnDownloadSmxCompleted(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow, ePlugin plugin)
{
    if(finished)
    {
        if(!StrEqual(error, ""))
        {
            LogMessageEx("Download %s Error: %s ", smxDLPath[plugin], error);
        }
        else
        {
            // download return error
            if(FileSize(smxDLPath[plugin]) < 1024)
            {
                char content[128];
                Handle file = OpenFile(smxDLPath[plugin], "r");
                ReadFileString(file, content, 128, -1);
                CloseHandle(file);
                PrintToServer("[%s] is checked -> %s", smxShort[plugin], content);
            }
            else
            {
                successList.Push(plugin);
                DeleteFile(smxPath[plugin]);
                RenameFile(smxPath[plugin], smxDLPath[plugin]);
                LogMessageEx("update [%s] successful -> size: %d bytes", smxShort[plugin], FileSize(smxPath[plugin]));
            }
            DeleteFile(smxDLPath[plugin]);
        }
        currentSmx--;
    }
}

public Action Timer_CheckSmxCompleted(Handle timer)
{
    static int times = 0;
    if(currentSmx > 0)
    {
        PrintToServer("Wating for download threads...  [threads: %d  | times: %d]", currentSmx, ++times);
        return Plugin_Continue;
    }
    
    Checking = false;

    if(successList.Length == 0)
        return Plugin_Stop;

    bool restart = false;
    for(int i = 0; i < successList.Length; ++i)
    {
        ePlugin plugin = successList.Get(i);
        if(plugin == pl_Core_main || plugin == pl_Shop_core)
        {
            restart = true;
            break;
        }
    }

    if(restart)
    {
        CreateTimer(0.5, Timer_RestartServer);
        for(int client = 1; client <= MaxClients; ++client)
            if(IsClientConnected(client))
                KickClient(client, "服务器核心模块更新完毕,\n正在重新启动服务器.\n请重新连接服务器!");
    }
    else
        for(int i = 0; i < successList.Length; ++i)
            ServerCommand("sm plugins reload %s", smxFile[successList.Get(i)]);

    return Plugin_Stop;
}

public Action Timer_RestartServer(Handle timer)
{
    LogMessageEx("All plugins are up to date, restarting server...");
    ServerCommand("exit");
    return Plugin_Stop;
}