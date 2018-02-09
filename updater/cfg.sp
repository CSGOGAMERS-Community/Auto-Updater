char baseURL[192];
char nextMap[128];

void CFG_OnAllPluginLoaded()
{
    RegAdminCmd("sm_updatecfg", Command_UpdaterCFG, ADMFLAG_BAN);
    
    if(FindPluginByFile("zombiereloaded.smx"))
        strcopy(baseURL, 192, "https://raw.githubusercontent.com/PuellaMagi/Server-Data/master/ZombieEscape");
    
    if(FindPluginByFile("mg_stats.smx"))
        strcopy(baseURL, 192, "https://raw.githubusercontent.com/PuellaMagi/Server-Data/master/MiniGames");
}

void CFG_OnMapStart(const char[] map)
{
    if(StrEqual(nextMap, map))
        return;
    
    OnMapVoteEnd(map);
}

public Action Command_UpdaterCFG(int client, int args)
{
    GetCurrentMap(nextMap, 128);

    CFG_GetTrans();
    CFG_GetConfs();
    CFG_GetStrip();
    CFG_GetWatch();
    
    if(client) PrintToChat(client, "Update Configs/Translations of %s", nextMap);
    else PrintToServer("Update Configs/Translations of %s", nextMap);

    return Plugin_Handled;
}

void CFG_GetTrans()
{
    if(baseURL[0] == '\0')
        return;

    char url[256], map[128], path[256];
    String_ToLower(nextMap, map, 128);
    Format(url, 256, "%s/map-translation/%s.txt", baseURL, map);
    Format(path, 256, "addons/sourcemod/data/download/%s.txt", map);
    System2_DownloadFile(CFG_OnTransCompleted, url, path);
}

public void CFG_OnTransCompleted(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow)
{
    if(finished)
    {
        char newFile[256], oldFile[256];
        Format(newFile, 256, "addons/sourcemod/data/download/%s.txt", nextMap);
        Format(oldFile, 256, "addons/sourcemod/data/mapchat/%s.txt", nextMap);

        if(!StrEqual(error, "") || FileSize(newFile) <= 32)
        {
            DeleteFile(newFile);

            if(StrContains(error, "Connection timed out after", false) == 0)
            {
                CFG_GetTrans();
                LogError("Download Translation[%s] Error: %s => Try again", nextMap, error);
            }
            else if(!StrEqual(error, ""))
                LogError("Download Translation[%s] Error: %s", nextMap, error);

            return;
        }

        DeleteFile(oldFile);
        RenameFile(oldFile, newFile);
        DeleteFile(newFile);

        PrintToServer("Preload %s successful!", oldFile);

        ServerCommand("sm_reloadchat");
    }
}

void CFG_GetConfs()
{
    if(baseURL[0] == '\0')
        return;

    char url[256], path[256];
    Format(url, 256, "%s/map-cfg/%s.cfg", baseURL, nextMap);
    Format(path, 256, "addons/sourcemod/data/download/%s.cfg", nextMap);
    System2_DownloadFile(CFG_OnConfsCompleted, url, path);
}

public void CFG_OnConfsCompleted(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow)
{
    if(finished)
    {
        char newFile[256], oldFile[256];
        Format(newFile, 256, "addons/sourcemod/data/download/%s.cfg", nextMap);
        Format(oldFile, 256, "cfg/sourcemod/map-cfg/%s.cfg", nextMap);
        
        if(FileSize(newFile) <= 32)
        {
            DeleteFile(newFile);
            LogError("Download Config[%s] Return: 404 -> need update config on GitHub", nextMap);
            return;
        }

        if(!StrEqual(error, ""))
        {
            DeleteFile(newFile);

            if(StrContains(error, "Connection timed out after", false) == 0)
            {
                CFG_GetConfs();
                LogError("Download Config[%s] Error: %s => Try again", nextMap, error);
            }
            else if(!StrEqual(error, ""))
                LogError("Download Config[%s] Error: %s", nextMap, error);

            return;
        }

        DeleteFile(oldFile);
        RenameFile(oldFile, newFile);
        DeleteFile(newFile);
        
        PrintToServer("Preload %s succssful!", oldFile);
        
        char map[128];
        GetCurrentMap(map, 128);
        ServerCommand("exec sourcemod/map-cfg/%s.cfg", map);
        PrintToServer("exec %s.cfg successful!", map);
    }
}

void CFG_GetStrip()
{
    if(baseURL[0] == '\0')
        return;

    char url[256], map[128], path[256];
    String_ToLower(nextMap, map, 128);
    Format(url, 256, "%s/map-stripper/%s.cfg", baseURL, map);
    Format(path, 256, "addons/sourcemod/data/download/%s_stripper.cfg", map);
    System2_DownloadFile(CFG_OnStripCompleted, url, path);
}

public void CFG_OnStripCompleted(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow)
{
    if(finished)
    {
        char newFile[256], oldFile[256];
        Format(newFile, 256, "addons/sourcemod/data/download/%s_stripper.cfg", nextMap);
        Format(oldFile, 256, "addons/stripper/maps/%s.cfg", nextMap);

        if(FileSize(newFile) <= 32)
        {
            DeleteFile(newFile);
            return;
        }

        if(!StrEqual(error, ""))
        {
            DeleteFile(newFile);

            if(StrContains(error, "Connection timed out after", false) == 0)
            {
                CFG_GetConfs();
                LogError("Download Stripper Config[%s] Error: %s => Try again", nextMap, error);
            }
            else if(!StrEqual(error, ""))
                LogError("Download Stripper Config[%s] Error: %s", nextMap, error);

            return;
        }

        DeleteFile(oldFile);
        RenameFile(oldFile, newFile);
        DeleteFile(newFile);

        PrintToServer("Preload %s succssful!", oldFile);
    }
}

void CFG_GetWatch()
{
    if(baseURL[0] == '\0')
        return;
    
    if(!FindPluginByFile("entWatch.smx"))
        return;

    char url[256], map[128], path[256];
    String_ToLower(nextMap, map, 128);
    Format(url, 256, "%s/map-entwatch/%s.cfg", baseURL, map);
    Format(path, 256, "addons/sourcemod/data/download/%s_entwatch.cfg", map);
    System2_DownloadFile(CFG_OnWatchCompleted, url, path);
}

public void CFG_OnWatchCompleted(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow)
{
    if(finished)
    {
        char newFile[256], oldFile[256];
        Format(newFile, 256, "addons/sourcemod/data/download/%s_entwatch.cfg", nextMap);
        Format(oldFile, 256, "cfg/sourcemod/entwatch/%s.cfg", nextMap);

        if(FileSize(newFile) <= 32)
        {
            DeleteFile(newFile);
            return;
        }

        if(!StrEqual(error, ""))
        {
            DeleteFile(newFile);

            if(StrContains(error, "Connection timed out after", false) == 0)
            {
                CFG_GetConfs();
                LogError("Download entWatch Config[%s] Error: %s => Try again", nextMap, error);
            }
            else if(!StrEqual(error, ""))
                LogError("Download entWatch Config[%s] Error: %s", nextMap, error);

            return;
        }

        DeleteFile(oldFile);
        RenameFile(oldFile, newFile);
        DeleteFile(newFile);

        PrintToServer("Preload %s succssful!", oldFile);
        ServerCommand("sm_entwatch_reload");
    }
}