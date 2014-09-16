$stream = [System.IO.StreamWriter] "c:\log.txt"
$epodate=(get-date )
$stream.WriteLine($epodate)
$count=$Args.Count
if ($count -gt 0) {
	foreach ($i in $Args) {
		$stream.WriteLine("Parametre fourni :" + $i)
		}
	}
$stream.close()