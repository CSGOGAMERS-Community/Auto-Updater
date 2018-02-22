void NAV_OnAllPluginLoaded()
{

}

void NAV_CheckMapNav(const char[] map)
{
    if(g_Game != Engine_CSGO)
        return;

    char navpath[128];
    FormatEx(navpath, 256, "maps/%s.nav", map);
    if(FileExists(navpath))
        return;

    char url[256], dwlpath[256];
    FormatEx(dwlpath, 256, "addons/sourcemod/data/download/%s.nav", map);
    FormatEx(url, 256, "https://static.csgogamers.com/navdownloader/unbz2.php?nav=%s", map);

    Handle pack = CreateDataPack();
    WritePackString(pack, map);
    ResetPack(pack);
    System2_DownloadFile(NAV_OnDownloadNAVCompleted, url, dwlpath, pack);
    
    LogMessage("NAV -> %s -> %s", map, url);
}

public void NAV_OnDownloadNAVCompleted(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow, Handle pack)
{
    if(!finished)
        return;

    char map[128];
    ReadPackString(pack, map, 128);
    delete pack;
    
    char dwlpath[256], navpath[256];
    FormatEx(dwlpath, 256, "addons/sourcemod/data/download/%s.nav", map);
    FormatEx(navpath, 256, "maps/%s.nav", map);

    if(!StrEqual(error, ""))
    {
        LogError("Download %s.nav.bz2 failed: %s", map, error);
        DeleteFile(dwlpath);
        return;
    }

    RenameFile(navpath, dwlpath);
    DeleteFile(dwlpath);
}