<html>
<head></head>
<body>

<?php
$dstr = date("Y-m-d H:i:s");
$h = gethostname();

print "<span  style=\"font-size: 36\">$h</span>";

echo "Last refreshed at: $dstr";

if (isset($_GET["action"])) {
   #echo "<hr>";
   $action = $_GET["action"];
   system("/home/jdmc2/amon/amon $action");
#   echo "Completed running \"amon $action\"";
}

echo "<hr>";


?>
<a href="amon.php"><button type="button">refresh</button></a>
<a href="amon.php?action=status"><button type="button">status</button></a>
<a href="amon.php?action=ping"><button type="button">ping</button></a>
<a href="amon.php?action=watchdog"><button type="button">watchdog</button></a>
<a href="amon.php?action=diskusage"><button type="button">diskusage</button></a>
<a href="/amondata"><button type="button">Browse Data</button></a>
<a href="amon.php?action=cleanup"><button type="button">cleanup</button></a>
|
<a href="amon.php?action=on"><button type="button" style="background-color:lightgreen">on</button></a>
<a href="amon.php?action=off"><button type="button" style="background-color:red">off</button></a>
<a href="amon.php?action=start"><button type="button" style="background-color:lightgreen">start</button></a>
<a href="amon.php?action=stop"><button type="button" style="background-color:red">stop</button></a>
|
<a href="amon.php?action=deep-clean"><button type="button">deep clean</button></a>
<br>


<?php
  echo "<hr><pre>";
  system('tail -20 /home/jdmc2/amon/amon.log | tac');
  echo "</pre>";
?>

</body>
</html>
