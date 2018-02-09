<?php 

if(!isset($_GET['plugin'])){
    echo 'Plugin ERROR';
    die(404);
}

if(!isset($_GET['file'])){
    echo 'File ERROR!';
    die(404);
}

if(!isset($_GET['md5'])){
    echo 'MD5 ERROR!';
    die(404);
}

switch(intval($_GET['plugin']))
{
    case 101, 102, 103, 104, 105, 201, 202, 203:
        $path = "/PuellaMagi/Raw";
        break;
    case 301, 302, 303, 304
        $path = "/MCR/Raw";
        break;
    case 401:
        $path = "/AMP/Raw";
        break;
    case 402:
        $path = "/Updater/Raw";
        break;
    default:
        echo 'Plugin ERROR!';
        die(404);
        break;
}

$file = __DIR__ . $path . "/" . $_GET['file'];

if(!file_exists($file)){
    echo 'Plugin NOT exists!';
    die(404);
}

$md5 = md5_file($file);

if(strcmp($md5, $_GET['md5']) == 0){
    echo 'Plugin ' . $_GET['plugin'] . ' is up to date';
    die(200);
}

header("HTTP/1.1 302 Moved temporarily");
header("Location: https://plugins.csgogamers.com$path/$_GET[file]");

?>