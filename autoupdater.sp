#pragma semicolon 1
#pragma newdecls required

#include <MagicGirl.NET>
#include <MagicGirl/vars>
#include <system2>

EngineVersion g_Game;
Database g_hDatabase;
bool testServer;

#include "updater/cfg.sp"   //自动更新cfg和翻译
#include "updater/map.sp"   //自动添加地图到服务器
#include "updater/nav.sp"   //自动更新nav
#include "updater/smx.sp"   //自动更新插件到服务器
#include "updater/add.sp"   //自动审核并添加地图到数据中心

public Plugin myinfo = 
{
    name        = "Auto Updater",
    author      = "Kyle",
    description = "an auto update system",
    version     = "2.0.<commit_count>.<commit_branch> - <commit_date>",
    url         = "https://02.ditf.moe"
};

void OnDatabaseAvailable()
{
    if(testServer)
        return;

    LogMessage("Auto-Updater is checking server [ %d ] now...", MG_Core_GetServerId());

    if(MG_Core_GetServerModId() == 199)
    {
        char m_szPath[128];
        BuildPath(Path_SM, m_szPath, 128, "plugins/autoupdater.smx");
        if(!FileExists(m_szPath) || !DeleteFile(m_szPath))
            LogError("Delete autoupdater.smx failed.");
        ServerCommand("sm plugins unload autoupdater.smx");
        return;
    }
    
    if(g_Game != Engine_CSGO)
        return;

    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "SELECT `map` FROM dxg_mapdb WHERE `mod` = '%d'", MG_Core_GetServerModId());
    g_hDatabase.Query(SQLCallback_CheckMap, m_szQuery);
    SMX_OnDatabaseAvailable();
}

public void OnAllPluginsLoaded()
{
    g_Game = GetEngineVersion();

    char szPath[128];
    BuildPath(Path_SM, szPath, 128, "data/download");
    if(!DirExists(szPath))
        CreateDirectory(szPath, 511);

    CheckDatabase();

    CFG_OnAllPluginLoaded();
    SMX_OnAllPluginLoaded();
    NAV_OnAllPluginLoaded();
    MAP_OnAllPluginLoaded();
    ADD_OnAllPluginLoaded();
}

void CheckDatabase()
{
    g_hDatabase = MG_MySQL_GetDatabase();
    if(g_hDatabase == null)
    {
        CreateTimer(5.0, Timer_Reconnect);
        return;
    }

    OnDatabaseAvailable();
}

public Action Timer_Reconnect(Handle timer)
{
    CheckDatabase();
    return Plugin_Stop;
}

public void OnConfigsExecuted()
{
    char map[128];
    GetCurrentMap(map, 128);
    CFG_OnMapStart(map);
    ADD_OnMapStart(map);
}

public void OnMapVoteEnd(const char[] map)
{
    if(StrContains(map, "extend", false) != -1)
        return;

    if(StrContains(map, "change", false) != -1)
        return;

    strcopy(nextMap, 128, map);

    NAV_CheckMapNav(map);

    CFG_GetTrans();
    CFG_GetConfs();
    CFG_GetStrip();
    CFG_GetWatch();
}

void String_ToLower(const char[] input, char[] output, int size)
{
    size--;

    int x = 0;
    while(input[x] != '\0' && x < size)
    {
        output[x] = CharToLower(input[x]);
        x++;
    }

    output[x] = '\0';
}