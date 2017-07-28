#!/usr/bin/php -q
<?php

$mongo = new \MongoDB\Driver\Manager('mongodb://192.168.0.105:27017/genieacs');
echo "Criada a instância";
//$id           = new \MongoDB\BSON\ObjectId("588c78ce02ac660426003d87");
$filter      = array('_id' => "/.*3B08EE7F/");
$options = array();

$query = new \MongoDB\Driver\Query($filter, $options);
$rows   = $mongo->executeQuery('db.collectionName', $query); 
print_r($rows);


foreach ($rows as $document) {
  print($document);
  }

/*
db.getCollection('devices').find({_id: /.*3B08EE7F$/}, {_id: 1})
*/

?>