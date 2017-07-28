<?php

$db = new Mongo("mongodb://192.168.0.105:27017/genieacs");
$list = $db->listCollections();
foreach ($list as $collection) {
    echo "$collection \n";
}

?>
