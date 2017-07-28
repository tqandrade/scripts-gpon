#!/usr/bin/php -q
<?php
$user = $argv[1];
$strSql = "select framedipaddress from radacct where username='$user' and acctstoptime is null"; 
$link = mysql_connect('192.168.0.49', 'radius', 'R4d1us#') or die("Falha ao conectar ao BD");
mysql_select_db('radius') or die("1");
$result = mysql_query($strSql);
while($r = mysql_fetch_assoc($result)){
  die($r['framedipaddress']);
}
?>