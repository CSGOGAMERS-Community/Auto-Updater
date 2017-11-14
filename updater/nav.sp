void NAV_OnAllPluginLoaded()
{
    
}

void NAV_GetFiles(const char[] map)
{
    char url[256], dwlpath[256], navpath[256];
    Format(dwlpath, 256, "addons/sourcemod/data/download/%s.nav", map);
    Format(navpath, 256, "maps/%s.nav", map);
    Format(url, 256, "https://static.csgogamers.com/navdownloader/unbz2.php?nav=%s", map);
    
    if(FileExists(navpath))
        return;
    
    Handle pack = CreateDataPack();
    WritePackString(pack, map);
    ResetPack(pack);
    System2_DownloadFile(NAV_OnDownloadNAVCompleted, url, dwlpath, pack);
}

public void NAV_OnDownloadNAVCompleted(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow, Handle pack)
{
    if(!finished)
        return;
    
    char map[128];
    ReadPackString(pack, map, 128);
    delete pack;
    
    char dwlpath[256], navpath[256];
    Format(dwlpath, 256, "addons/sourcemod/data/download/%s.nav", map);
    Format(navpath, 256, "maps/%s.nav", map);

    if(!StrEqual(error, ""))
    {
        LogError("Download %s.nav.bz2 failed: %s", map, error);
        DeleteFile(dwlpath);
        return;
    }

    RenameFile(navpath, dwlpath);
    DeleteFile(dwlpath);
}