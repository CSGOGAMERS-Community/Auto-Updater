<?php 

$path = __DIR__ . "/" . $_GET['plugin'] . "/Raw/" . $_GET['plugin'] . ".smx";

if(!file_exists($path)){
    echo 'Plugin ERROR!';
    die(404);
}

if(!isset($_GET['md5'])){
    echo 'MD5 ERROR!';
    die(404);
}

$md5 = md5_file($path);

if(strcmp($md5, $_GET['md5']) == 0){
    echo 'Plugin '. $_GET['plugin'] . ' is up to date';
    die(200);
}

header("HTTP/1.1 302 Moved temporarily");
header("Location: https://plugins.csgogamers.com/$_GET[plugin]/Raw/$_GET[plugin].smx");

?>