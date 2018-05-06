char currentMap[128];
char currentUrl[256];

void MAP_OnAllPluginLoaded()
{
    if(g_Game != Engine_CSGO)
        return;

    RegAdminCmd("sm_updatemap", Command_UpdateMap, ADMFLAG_BAN);
    RegAdminCmd("sm_deletemap", Command_DeleteMap, ADMFLAG_BAN);
    CreateTimer(1800.0, Timer_CheckUpdateMap, _, TIMER_REPEAT);
}

public void SQLCallback_CheckMap(Database db, DBResultSet results, const char[] error, int startCheck)
{
    if(results == null || error[0])
    {
        LogMessageEx("load map list from database failed:  %s", error);
        return;
    }

    if(results.RowCount < 1)
    {
        LogMessageEx("map list from database is null! Now inserting!");
        InsertMapsToDatabase();
        return;
    }

    LogMessageEx("Syncing Map from database!");

    char map[128];

    ArrayList array_mapmysql = CreateArray(ByteCountToCells(128));
    while(results.FetchRow())
    {
        results.FetchString(0,  map, 128);
        PushArrayString(array_mapmysql, map);
    }
    
    if(startCheck == 0)
        CheckMapsOnStart(array_mapmysql);
    else
        CheckMapsOnDelete(array_mapmysql, startCheck);

    delete array_mapmysql;
    
    LogMessageEx("Map list has been synced");
}

void InsertMapsToDatabase()
{
    Handle hDirectory;
    if((hDirectory = OpenDirectory("maps")) != INVALID_HANDLE)
    {
        FileType type = FileType_Unknown;
        char filename[128];
        while(ReadDirEntry(hDirectory, filename, 128, type))
        {
            if(type != FileType_File)
                continue;
            
            TrimString(filename);

            if(StrContains(filename, ".bsp", false) == -1)
                continue;
            
            ReplaceString(filename, 128, ".bsp", "", false);
            
            char path[128], crc32[33];
            FormatEx(path, 128, "maps/%s.bsp", filename);
            
            if(System2_GetFileCRC32(path, crc32, 33))
            {
                char m_szMap[128], m_szQuery[256];
                SQL_EscapeString(g_hDatabase, filename, m_szMap, 128);
                FormatEx(m_szQuery, 256, "INSERT INTO dxg_mapdb VALUES ('%d', '%s', '%s');", MG_Core_GetServerModId(), m_szMap, crc32);
                MG_MySQL_SaveDatabase(m_szQuery);
                LogMessageEx("Insert %s to database -> CRC[%s]", filename, crc32);
            }
            else
                LogMessageEx("Get %s CRC32 failed!", path);
        }
        CloseHandle(hDirectory);
    }
    
    CreateTimer(1.0, Timer_ChangeMap);
    CreateTimer(9.9, Timer_RestartSV);
}

void CheckMapsOnStart(ArrayList array_mapmysql)
{
    ArrayList array_maplocal = CreateArray(ByteCountToCells(128));
    int mapListSerial = -1;
    if(ReadMapList(array_maplocal, mapListSerial, "default", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_NO_DEFAULT) == INVALID_HANDLE)
        if(mapListSerial == -1)
            return;
        
    int arraysize_maplocal = GetArraySize(array_maplocal);
    
    bool deleted;
    
    char map[128];
    
    for(int index = 0; index < arraysize_maplocal; ++index)
    {
        array_maplocal.GetString(index, map, 128);
        
        if(strlen(map) < 3) continue;
        
        if(FindStringInArray(array_mapmysql, map) != -1)
        {
            NAV_CheckMapNav(map);
            continue;
        }    
        
        char bsp[128];
        FormatEx(bsp, 128, "maps/%s.bsp", map);
        LogMessageEx("Delete %s %s!", bsp, DeleteFile(bsp) ? "successful" : "failed");

        char nav[128];
        FormatEx(nav, 128, "maps/%s.nav", map);
        LogMessageEx("Delete %s %s!", nav, DeleteFile(nav) ? "successful" : "failed");

        deleted = true;
    }

    delete array_maplocal; 

    if(deleted)
    {
        CreateTimer(1.0, Timer_ChangeMap);
        CreateTimer(9.9, Timer_RestartSV);
    }
}

public Action Timer_ChangeMap(Handle timer)
{
    char map[128];
    GetCurrentMap(map, 128);
    map[2] = '\0';
    ForceChangeLevel(map, "restart map");
    return Plugin_Stop;
}

public Action Timer_RestartSV(Handle timer)
{
    ServerCommand("exit");
    return Plugin_Stop;
}

public Action Timer_CheckUpdateMap(Handle timer)
{
    CheckingNewMap();
    return Plugin_Continue;
}

void CheckingNewMap()
{
    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "SELECT `id`, `map` FROM `dxg_mapupdate` WHERE `sid` = '%d' AND `done` = '0' AND `try` < '3' ORDER BY id ASC LIMIT 1", MG_Core_GetServerId());
    g_hDatabase.Query(SQLCallback_GetNewMap, m_szQuery);
}

public void SQLCallback_GetNewMap(Database db, DBResultSet results, const char[] error, any unuse)
{
    if(results == null || error[0])
    {
        LogMessageEx("Checking new map list failed: %s", error);
        return;
    }
    
    if(!results.FetchRow())
        return;

    results.FetchString(1, currentMap, 128);
    
    FormatEx(currentUrl, 256, "http://maps.csgogamers.com/%s.bsp.bz2", currentMap);

    if(currentMap[0] == '\0' || strlen(currentUrl) <= 35)
    {
        PrintToServer("invalid map from database");
        return;
    }

    char path[256];
    FormatEx(path, 256, "addons/sourcemod/data/download/%s.bsp.bz2", currentMap);
    System2_DownloadFile(MAP_OnDownloadMapCompleted, currentUrl, path);

    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "UPDATE dxg_mapupdate SET try=try+1 WHERE id=%d", results.FetchInt(0));
    MG_MySQL_SaveDatabase(m_szQuery);

    PrintToServer("Download %s from %s", currentMap, currentUrl);
}

public void MAP_OnDownloadMapCompleted(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow)
{
    PrintToServer("[%.2f%%] Downloading %s.bsp.bz2 ", (dlnow/dltotal)*100, currentMap);

    if(finished)
    {
        if(!StrEqual(error, ""))
        {
            LogMessageEx("Download %s.bsp.bz2 form %s failed: %s", currentMap, currentUrl, error);
            char path[256];
            FormatEx(path, 256, "addons/sourcemod/data/download/%s.bsp.bz2", currentMap);
            DeleteFile(path);
            
            currentMap[0] = '\0';
            currentUrl[0] = '\0';
        
            CheckingNewMap();

            return;
        }

        char path[256];
        FormatEx(path, 256, "addons/sourcemod/data/download/%s.bsp.bz2", currentMap);
        System2_ExtractArchive(MAP_OnBz2ExtractCompleted, path, "addons/sourcemod/data/download/");

        PrintToServer("ExtractArchive %s to addons/sourcemod/data/download/%s.bsp", path, currentMap);
    }
}

public void MAP_OnBz2ExtractCompleted(const char[] output, const int size, CMDReturn status)
{
    if(status == CMD_SUCCESS)
    {
        char path[256], maps[256];
        FormatEx(path, 256, "addons/sourcemod/data/download/%s.bsp", currentMap);
        FormatEx(maps, 256, "maps/%s.bsp", currentMap);

        System2_CopyFile(MAP_OnMapCopyCompleted, path, maps);
        
        PrintToServer("Copy %s to %s", path, maps);
    }
    else if(status == CMD_ERROR)
    {
        LogMessageEx("Bz2 Extract addons/sourcemod/data/download/%s.bsp.bz2 failed: \n%s", currentMap, output);

        char path[256];
        FormatEx(path, 256, "addons/sourcemod/data/download/%s.bsp.bz2", currentMap);
        DeleteFile(path);

        currentMap[0] = '\0';
        currentUrl[0] = '\0';
        
        CheckingNewMap();
    }
}

public void MAP_OnMapCopyCompleted(bool success, const char[] from, const char[] to)
{
    if(success)
    {
        if(!IsMapValid(currentMap))
        {
            DeleteFile(to);
            LogMessageEx("Validate %s failed!",  currentMap);
        }

        char del[256];

        FormatEx(del, 256, "addons/sourcemod/data/download/%s.bsp.bz2", currentMap);
        if(!DeleteFile(del))
            LogMessageEx("Delete %s failed.",  del);

        FormatEx(del, 256, "addons/sourcemod/data/download/%s.bsp", currentMap);
        if(!DeleteFile(del))
            LogMessageEx("Delete %s failed.",  del);
        
        UpdateMapStatus();
        CheckingNewMap();
        
        PrintToServer("Add new map %s successful!", currentMap);
    }
}

void UpdateMapStatus()
{
    char m_szQuery[256], emap[128];
    g_hDatabase.Escape(currentMap, emap, 128);
    FormatEx(m_szQuery, 512, "UPDATE dxg_mapupdate SET done = 1 WHERE sid = %d AND map = '%s'", MG_Core_GetServerId(), emap);
    MG_MySQL_SaveDatabase(m_szQuery);

    currentMap[0] = '\0';
    currentUrl[0] = '\0';
}

public Action Command_UpdateMap(int client, int args)
{
    CheckingNewMap();

    return Plugin_Handled;
}

public Action Command_DeleteMap(int client, int args)
{
    if(!client)
        return Plugin_Handled;
    
    if(g_Game != Engine_CSGO)
        return Plugin_Handled;

    char auth[32];
    GetClientAuthId(client, AuthId_Steam2, auth, 32, true);
    
    AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, auth);

    if(admin == INVALID_ADMIN_ID)
        return Plugin_Handled;
    
    if(GetAdminImmunityLevel(admin) < 50)
        return Plugin_Handled;

    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "SELECT `map` FROM dxg_mapdb WHERE `mod` = '%d'", MG_Core_GetServerModId());
    g_hDatabase.Query(SQLCallback_CheckMap, m_szQuery, client);

    return Plugin_Handled;
}

void CheckMapsOnDelete(ArrayList array_mapmysql, int client)
{
    if(!IsClientInGame(client))
        return;
    
    char auth[32];
    GetClientAuthId(client, AuthId_Steam2, auth, 32, true);
    
    AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, auth);
    
    if(admin == INVALID_ADMIN_ID)
        return;
    
    if(GetAdminImmunityLevel(admin) < 50)
        return;
    
    Handle menu = CreateMenu(MenuHandler_DeleteMap);
    SetMenuTitle(menu, "Delete map menu");
    
    char map[128];
    int array_size = GetArraySize(array_mapmysql);
    for(int index = 0; index < array_size; ++index)
    {
        array_mapmysql.GetString(index, map, 128);
        AddMenuItem(menu, map, map);
    }

    DisplayMenu(menu, client, 0);
}

public int MenuHandler_DeleteMap(Handle menu, MenuAction action, int client, int param2)
{
    switch(action)
    {
        case MenuAction_End: CloseHandle(menu);
        case MenuAction_Select:
        {
            char info[128];
            GetMenuItem(menu, param2, info, 128);
            BuildConfirmMenu(client, info);
        }
    }
}

void BuildConfirmMenu(int client, const char[] info)
{
    Handle menu = CreateMenu(MenuHandler_Confirm);
    SetMenuTitle(menu, "Confirm delete? \n-> %s", info);
    SetMenuExitButton(menu, false);

    AddMenuItem(menu, " ", " ", ITEMDRAW_SPACER);
    AddMenuItem(menu, " ", " ", ITEMDRAW_SPACER);
    AddMenuItem(menu, " ", " ", ITEMDRAW_SPACER);
    AddMenuItem(menu, " ", " ", ITEMDRAW_SPACER);

    AddMenuItem(menu, info, "sure");
    AddMenuItem(menu, "no", "exit");
    
    DisplayMenu(menu, client, 0);
}

public int MenuHandler_Confirm(Handle menu, MenuAction action, int client, int param2)
{
    switch(action)
    {
        case MenuAction_End: CloseHandle(menu);
        case MenuAction_Select:
        {
            char info[128];
            GetMenuItem(menu, param2, info, 128);
            if(StrEqual(info, "no"))
                return;

            UTIL_DeleteMap(client, info);
        }
    }
}

void UTIL_DeleteMap(int client, const char[] map)
{
    char m_szQuery[256];
    Format(m_szQuery, 256, "DELETE FROM dxg_mapdb WHERE map = '%s'", map);
    MG_MySQL_SaveDatabase(m_szQuery);
    
    PrintToChat(client, "[\x07MAP\x01]  已从数据库中删除该地图.");
    PrintToChat(client, "[\x07MAP\x01]  当前服务器将在下次启动时,从本地删除地图.");
}