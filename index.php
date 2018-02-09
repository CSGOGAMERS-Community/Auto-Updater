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

switch($_GET['plugin'])
{
    case 101:
	case 102:
	case 103:
	case 104:
	case 105:
	case 201:
	case 202:
	case 203:
        $path = "/PuellaMagi/Raw";
        break;
    case 301:
	case 302:
	case 303:
	case 304:
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
        break;
}

$file = __DIR__ . $path . "/" . $_GET['file'];

if(!file_exists($file)){
    echo 'Plugin NOT exists!';
    die(404);
}

$md5 = md5_file($file);

if(strcmp($md5, $_GET['md5']) == 0){
    echo 'Plugin ' . $_GET['file'] . ' is up to date';
    die(200);
}

$loc = $path . "/" . $_GET['file'];
header("HTTP/1.1 302 Moved temporarily");
header("Location: https://plugins.csgogamers.com/$loc");

?>