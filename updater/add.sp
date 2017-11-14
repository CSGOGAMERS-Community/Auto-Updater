char downloadUrl[256];
char downloadMap[128];
char downloadTmp[256];
char serverType[4];
bool isBigMap;

void ADD_OnAllPluginLoaded()
{
    RegAdminCmd("sm_updateadd", Command_UpdaterADD, ADMFLAG_BAN);
    if(FindPluginByFile("store.smx"))
        return;

    char szPath[128];
    BuildPath(Path_SM, szPath, 128, "data/download/add/");
    if(!DirExists(szPath))
        CreateDirectory(szPath, 511);

    testServer = true;

    CreateTimer(300.0, Timer_CheckAddMap, _, TIMER_REPEAT);
}

// Admin command
public Action Command_UpdaterADD(int client, int args)
{
    CheckAddMap();
    return Plugin_Handled;
}

// Global check timer
public Action Timer_CheckAddMap(Handle timer)
{
    CheckAddMap();
    return Plugin_Continue;
}

// Check function
void CheckAddMap()
{
    if(serverType[0] != '\0')
    {
        LogMessage("In Download Process...");
        return;
    }

    SQL_TQuery(g_hDatabase, SQLCallback_GetAddMap, "SELECT `id`,`type`,`map`,`url` FROM `map_request` WHERE `done` = '%d' AND `try` < '3' ORDER BY id ASC LIMIT 1");
    LogMessage("Checking add map from databases");
}

// Reset stats and check
void Recheck()
{
    if(downloadTmp[0] != '\0')
        DeleteFile(downloadTmp);

    downloadUrl[0] = '\0';
    downloadMap[0] = '\0';
    downloadTmp[0] = '\0';
    serverType[0] = '\0';
    isBigMap = false;

    CheckAddMap();
}

// SQL callback
public void SQLCallback_GetAddMap(Handle owner, Handle hndl, const char[] error, any unuse)
{
    // If is not test server, then stop.
    if(!testServer)
        return;

    // SQL handle is not valid.
    if(owner == INVALID_HANDLE || hndl == INVALID_HANDLE)
    {
        LogError("Checking add map list failed: %s", error);
        return;
    }

    // Has no map in database.
    if(!SQL_FetchRow(hndl))
    {
        LogMessage("no add map from database");
        return;
    }

    // SQL fetch row
    char map[128];
    SQL_FetchString(hndl, 1, serverType, 4);
    SQL_FetchString(hndl, 2, map, 128);
    SQL_FetchString(hndl, 3, downloadUrl, 256);
    
    // Remove ext from map name.
    ReplaceString(map, 128, ".bsp", "", false);
    ReplaceString(map, 128, "bsp", "", false);
    ReplaceString(map, 128, ".bz2", "", false);
    ReplaceString(map, 128, "bz2", "", false);
    
    // Use lower string
    String_ToLower(map, downloadMap, 128);

    // Tell database we have been checked.
    char m_szQuery[128];
    Format(m_szQuery, 128, "UPDATE map_request SET try=try+1 WHERE id=%d", SQL_FetchInt(hndl, 0));
    CG_DatabaseSaveGames(m_szQuery);
    
    if(!NotFollowGameMode(serverType, map))
    {
        LogFileEx("NotFollowGameMode: %s %s %s", serverType, map, downloadUrl);
        Recheck();
        return;
    }

    // Unknown type, invalid url, invalid map name, then stop.
    if(!StrEqual(serverType, "no") || strlen(downloadUrl) > 30 || strlen(downloadMap) > 1)
    {
        // Find fully dl file name from url
        char temp[128];
        strcopy(temp, 128, downloadUrl[FindCharInString(downloadUrl, '/', true)+1]);
        
        // Prepare local file path.
        Format(downloadTmp, 256, "addons/sourcemod/data/download/add/%s", temp);
        
        // Starting download file.
        System2_DownloadFile(ADD_OnDownloadMapCompleted, downloadUrl, downloadTmp);

        LogFileEx("Download %s from %s", downloadMap, downloadUrl);
        return;
    }

    LogError("invalid map from database");

    // Recheck.
    Recheck();
}

public void ADD_OnDownloadMapCompleted(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow)
{
    // Print processor in console.
    PrintToServer("[%.2f%%] Downloading %s ", (dlnow/dltotal)*100, downloadUrl);

    if(finished)
    {
        // If has error, then stop.
        if(!StrEqual(error, ""))
        {
            LogFileEx("Download %s form %s failed: %s", downloadMap, downloadUrl, error);
            Recheck();
            return;
        }
        
        // If file is not valid, then stop.
        if(FileSize(downloadTmp) < 10240)
        {
            DeleteFile(downloadTmp);
            LogFileEx("Download %s form %s failed: file is not valid", downloadMap, downloadUrl);
            Recheck();
            return;
        }

        // UnArchive file.
        System2_ExtractArchive(ADD_OnBz2ExtractCompleted, downloadTmp, "addons/sourcemod/data/download/add/");

        // Print processor in console.
        LogFileEx("ExtractArchive %s to addons/sourcemod/data/download/add/", downloadTmp);
    }
}

public void ADD_OnBz2ExtractCompleted(const char[] output, const int size, CMDReturn status)
{
    if(status == CMD_SUCCESS)
    {
        // Prepare file path.
        char path[256], move[256];
        Format(path, 256, "addons/sourcemod/data/download/add/%s.bsp", downloadMap);
        
        if(FileExists(path) || FindBspFile(path))
        {
            // File exists then move file to /maps folder.
            Format(move, 256, "maps/%s.bsp", downloadMap);
            System2_CopyFile(ADD_OnMapCopyCompleted, path, move);
            LogFileEx("Copy %s to %s", path, move);
            return;
        }
        
        LogFileEx("after extract archive, not found %s.bsp in %s", downloadMap, path);
        Recheck();
    }
    else if(status == CMD_ERROR)
    {
        LogFileEx("Bz2 Extract %s failed: \n%s", downloadTmp, output);
        Recheck();
    }
}

bool FindBspFile(char[] path)
{
    bool result = false;
    char bsp[128];
    Format(bsp, 128, "%s.bsp", downloadMap);

    Handle hDirectory;
    if((hDirectory = OpenDirectory("addons/sourcemod/data/download/add/")) != INVALID_HANDLE)
    {
        FileType type = FileType_Unknown;
        char filename[128];
        while(ReadDirEntry(hDirectory, filename, 128, type))
        {
            if(type != FileType_File)
                continue;
            
            char filepath[256];
            Format(filepath, 256, "addons/sourcemod/data/download/add/%s", filename);
            LogMessage("Find %s", filepath);

            if(StrEqual(filename, bsp, false) && !result)
            {
                Format(path, 256, "addons/sourcemod/data/download/add/%s", bsp);
                LogFileEx("Find bsp file %s", RenameFile(path, filepath) ? "successful!" : "failed!");
                result = true;
            }
        }
        CloseHandle(hDirectory);
    }

    return result;
}

public void ADD_OnMapCopyCompleted(bool success, const char[] from, const char[] to)
{
    if(success)
    {
        // delete all file
        Handle hDirectory;
        if((hDirectory = OpenDirectory("addons/sourcemod/data/download/add/")) != INVALID_HANDLE)
        {
            FileType type = FileType_Unknown;
            char filename[128];
            while(ReadDirEntry(hDirectory, filename, 128, type))
            {
                if(type == FileType_Unknown)
                    continue;

                char path[256];
                Format(path, 256, "addons/sourcemod/data/download/add/%s", filename);
                if(!DeleteFile(path))
                    LogFileEx("Delete %s failed.",  path);
            }
            CloseHandle(hDirectory);
        }

        // Check map validate.
        if(!IsMapValid(downloadMap))
        {
            // If not valid then delete this.
            DeleteFile(to);
            LogFileEx("Validate %s failed!",  downloadMap);
            Recheck();
            return;
        }
        
        // Change map to check map.
        ForceChangeLevel(downloadMap, "test");
    }
}

void ADD_OnMapStart(const char[] map)
{
    if(!testServer || !StrEqual(map, downloadMap))
        return;
    
    // OK, now all check is done.
    char bsp[128], path[256];
    Format(bsp, 128, "maps/%s.bsp", downloadMap);
    Format(path, 256, "addons/sourcemod/data/download/%s.bsp.bz2", downloadMap);
    
    // Compress Bz2 map file.
    System2_CompressFile(ADD_OnBz2Completed, bsp, path, ARCHIVE_BZIP2, LEVEL_5);

    // Print processor to console.
    LogFileEx("All check is done. Start Compress file %s", downloadMap);
}

public void ADD_OnBz2Completed(const char[] output, const int size, CMDReturn status)
{
    if(status == CMD_SUCCESS)
    {
        // If success then delete map file.
        char oldfile[128];
        Format(oldfile, 128, "maps/%s.bsp", downloadMap);
        
        isBigMap = (FileSize(oldfile) >= 157286400);

        if(!isBigMap && !DeleteFile(oldfile))
            LogFileEx("Delete %s failed.", oldfile);

        // Upload bz2 file to CG download center.
        char path[256], remote[256];
        Format(path, 256, "addons/sourcemod/data/download/%s.bsp.bz2", downloadMap);
        Format(remote, 256, "/%s.bsp.bz2", downloadMap);
        
        char host[32], port[32], user[32], pswd[32];
        CG_GetVariable("ftp_maps_host", host, 32);
        CG_GetVariable("ftp_maps_port", port, 32);
        CG_GetVariable("ftp_maps_user", user, 32);
        CG_GetVariable("ftp_maps_pswd", pswd, 32);
        System2_UploadFTPFile(ADD_OnFTPUploadCompleted_CG, path, remote, host, user, pswd, StringToInt(port));
    }
    else if(status == CMD_ERROR)
    {
        LogFileEx("bz2 CompressFile %s failed.", downloadMap);

        char oldfile[128];
        Format(oldfile, 128, "maps/%s.bsp", downloadMap);
        if(!DeleteFile(oldfile))
            LogFileEx("Delete %s failed.", oldfile);
        
        Recheck();
    }
}

public void ADD_OnFTPUploadCompleted_CG(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow)
{
    PrintToServer("[%.2f%%] FTP to CG %s ", (ulnow/ultotal)*100, downloadMap);
    if(finished)
    {
        LogFileEx("FTP Upload %s to CG finished. %s", downloadMap, error);
        
        if(StrContains(error, "response reading failed", false) != -1 || StrContains(error, "time out", false) != -1)
        {
            CreateTimer(5.0, Timer_ReFTP, 0);
            return;
        }
    
        if(!StrEqual(error, ""))
        {
            Recheck();
            return;
        }
        
        char path[256], remote[256];
    
        if(!isBigMap)
        {
            Format(path, 256, "addons/sourcemod/data/download/%s.bsp.bz2", downloadMap);
            Format(remote, 256, "/maps/%s.bsp.bz2", downloadMap);
        }
        else
        {
            Format(path, 256, "maps/%s.bsp", downloadMap);
            Format(remote, 256, "/maps/%s.bsp", downloadMap);
            CreateTimer(0.1, Timer_Delay2);
        }

        char host[32], port[32], user[32], pswd[32];
        CG_GetVariable("ftp_fast_host", host, 32);
        CG_GetVariable("ftp_fast_port", port, 32);
        CG_GetVariable("ftp_fast_user", user, 32);
        CG_GetVariable("ftp_fast_pswd", pswd, 32);
        System2_UploadFTPFile(ADD_OnFTPUploadCompleted_DL, path, remote, host, user, pswd, StringToInt(port));
    }
}

public void ADD_OnFTPUploadCompleted_DL(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow)
{
    PrintToServer("[%.2f%%] FTP to DL %s ", (ulnow/ultotal)*100, downloadMap);
    if(finished)
    {    
        LogFileEx("FTP Upload %s to DL finished. %s", downloadMap, error);
        
        if(StrContains(error, "response reading failed", false) != -1 || StrContains(error, "time out", false) != -1)
        {
            CreateTimer(5.0, Timer_ReFTP, 1);
            return;
        }
        
        if(!StrEqual(error, ""))
        {
            Recheck();
            return;
        }

        CreateTimer(0.1, Timer_Delay);
    }
}

public Action Timer_ReFTP(Handle timer, int type)
{
    if(type == 0)
    {
        // Upload bz2 file to CG download center.
        char path[256], remote[256];
        Format(path, 256, "addons/sourcemod/data/download/%s.bsp.bz2", downloadMap);
        Format(remote, 256, "/%s.bsp.bz2", downloadMap);
        
        char host[32], port[32], user[32], pswd[32];
        CG_GetVariable("ftp_maps_host", host, 32);
        CG_GetVariable("ftp_maps_port", port, 32);
        CG_GetVariable("ftp_maps_user", user, 32);
        CG_GetVariable("ftp_maps_pswd", pswd, 32);
        System2_UploadFTPFile(ADD_OnFTPUploadCompleted_CG, path, remote, host, user, pswd, StringToInt(port));
    }
    
    if(type == 1)
    {
        // Upload bz2 file to DL Server.
        char path[256], remote[256];
    
        if(!isBigMap)
        {
            Format(path, 256, "addons/sourcemod/data/download/%s.bsp.bz2", downloadMap);
            Format(remote, 256, "/maps/%s.bsp.bz2", downloadMap);
        }
        else
        {
            Format(path, 256, "maps/%s.bsp", downloadMap);
            Format(remote, 256, "/maps/%s.bsp", downloadMap);
        }

        char host[32], port[32], user[32], pswd[32];
        CG_GetVariable("ftp_fast_host", host, 32);
        CG_GetVariable("ftp_fast_port", port, 32);
        CG_GetVariable("ftp_fast_user", user, 32);
        CG_GetVariable("ftp_fast_pswd", pswd, 32);
        System2_UploadFTPFile(ADD_OnFTPUploadCompleted_DL, path, remote, host, user, pswd, StringToInt(port));
    }
    
    return Plugin_Stop;
}

public Action Timer_Delay(Handle timer)
{
    char path[256];
    if(!isBigMap)
        Format(path, 256, "addons/sourcemod/data/download/%s.bsp.bz2", downloadMap);
    else
        Format(path, 256, "maps/%s.bsp", downloadMap);
    if(!DeleteFile(path))
        LogFileEx("Delete %s failed.", path);

    InsertToDataBase();
    
    return Plugin_Stop;
}

public Action Timer_Delay2(Handle timer)
{
    char path[256];
    Format(path, 256, "addons/sourcemod/data/download/%s.bsp.bz2", downloadMap);
    if(!DeleteFile(path))
        LogFileEx("Delete %s failed.", path);

    return Plugin_Stop;
}

void InsertToDataBase()
{
    char m_szQuery[512], emap[128];
    
    SQL_EscapeString(g_hDatabase, downloadMap, emap, 128);
    Format(m_szQuery, 512, "UPDATE map_request SET done = 1 WHERE type = '%s' and map = '%s'", serverType, emap);
    CG_DatabaseSaveGames(m_szQuery);
    
    if(StrEqual(serverType, "tt"))
    {
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT, 5, 0, '%s', 0)", emap);
        CG_DatabaseSaveGames(m_szQuery);
        
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT, 6, 0, '%s', 0)", emap);
        CG_DatabaseSaveGames(m_szQuery);
    }
    else if(StrEqual(serverType, "ze"))
    {
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT, 1, 0, '%s', 0)", emap);
        CG_DatabaseSaveGames(m_szQuery);
        
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT, 2, 0, '%s', 0)", emap);
        CG_DatabaseSaveGames(m_szQuery);
        
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT, 3, 0, '%s', 0)", emap);
        
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT, 4, 0, '%s', 0)", emap);
        CG_DatabaseSaveGames(m_szQuery);
    }
    else if(StrEqual(serverType, "mg"))
    {
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT, 7, 0, '%s', 0)", emap);
        CG_DatabaseSaveGames(m_szQuery);
    }
    else if(StrEqual(serverType, "jb"))
    {
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT, 8, 0, '%s', 0)", emap);
        CG_DatabaseSaveGames(m_szQuery);
        
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT, 9, 0, '%s', 0)", emap);
        CG_DatabaseSaveGames(m_szQuery);
    }
    else if(StrEqual(serverType, "hg"))
    {
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT,11, 0, '%s', 0)", emap);
        CG_DatabaseSaveGames(m_szQuery);
    }
    else if(StrEqual(serverType, "ds"))
    {
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT,12, 0, '%s', 0)", emap);
        CG_DatabaseSaveGames(m_szQuery);
    }
    else if(StrEqual(serverType, "kz"))
    {
        Format(m_szQuery, 512, "INSERT INTO map_update VALUES (DEFAULT,15, 0, '%s', 0)", emap);
        CG_DatabaseSaveGames(m_szQuery);
    }

    ForceChangeLevel("de_dust2", "Reset");
    Recheck();
}

void LogFileEx(const char[] buffer, any ...)
{
    char fmt[256];
    VFormat(fmt, 256, buffer, 2);
    LogToFileEx("addons/sourcemod/data/addmap.txt", fmt);
}

bool NotFollowGameMode(const char[] type, const char[] map)
{
    if(StrEqual(type, "tt") && StrContains(map, "ttt_") != 0)
        return false;
    
    if(StrEqual(type, "ze") && StrContains(map, "ze_") != 0)
        return false;
    
    if(StrEqual(type, "mg") && StrContains(map, "mg_") != 0)
        return false;
    
    if(StrEqual(type, "hg") && StrContains(map, "hg_") != 0)
        return false;
    
    if(StrEqual(type, "ds") && StrContains(map, "surf_") != 0)
        return false;
    
    if(StrEqual(type, "jb") && StrContains(map, "jb_") != 0 && StrContains(map, "ba_") != 0)
        return false;
    
    if(StrEqual(type, "kz") && StrContains(map, "kz_") != 0 && StrContains(map, "bkz_") != 0 && StrContains(map, "kzpro_") != 0 && StrContains(map, "xc_") != 0)
        return false;
    
    return true;
}