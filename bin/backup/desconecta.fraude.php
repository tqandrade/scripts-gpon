#!/usr/bin/php -q
<?php
	$strSql = "
	select radacct.username, framedipaddress, acctsessionid, nasportid, nasipaddress from radacct
        inner join (select username from radacct where acctstoptime is null and nasportid regexp '[0-9]{2}[0-9]?[0-9]?\$' group by username having count(distinct acctsessionid)>1) T
        on T.username=radacct.username
        inner join instalacao_compacta i
        on i.codinst=radacct.username
        inner join rede r
        on r.cod_rede=i.cod_rede
        where
        ( radacct.nasportid<>r.vlan and r.vlan is not null)
        AND radacct.framedipaddress not like '172.%'
        AND radacct.username regexp '[0-9]*'
        AND i.maccontrolenabled=-1
        AND radacct.acctstoptime is null
        and radacct.nasportid regexp '^[0-9]{2}[0-9]?[0-9]?\$'
	";
	$link = mysql_connect('192.168.0.49', 'radius', 'R4d1us#') or die("Falha ao conectar ao BD");
	mysql_select_db('radius') or die("1");
	
	$result = mysql_query($strSql);
	while($r = mysql_fetch_assoc($result)){
			echo exec(sprintf("echo 'Acct-Session-Id=%s' | radclient -x %s disconnect somepassword", $r['acctsessionid'], $r['nasipaddress']));
	}
?>