# Задаем кодовую страницу
chcp.com 1251

# задаем параметры доступа
$cver = '8.3.12.1685'
$cserverRAS = 'app:38312'

# путь до RAC
$cpath = $env:ProgramFiles + '\1cv8\' + $cver + '\bin\rac.exe'
$bases1c = 'afm_ut_demo_test_mp_kurkov'


# разбираем вывод от RAC в объекты
function RacOutToObject($rac_out) 
{
  $objectList = @()  
  $object     = New-Object -TypeName PSObject      

  FOREACH ($line in $rac_out) 
  {
    #Write-Host "raw: _ $line _"

    if (([string]::IsNullOrEmpty($line))) 
    {
      $objectList += $object
      $object     = New-Object -TypeName PSObject 
    }

    # Remove the whitespace at the beginning on the line
    $line = $line -replace '^\s+', ''
   
    $keyvalue = $line -split ':'
	
    $key     = $keyvalue[0] -replace '^\s+', ''
    $value   = $keyvalue[1] -replace '^\s+', ''

    $key	 = $key.trim() -replace '-', '_'
    $value = $value.trim()

    if (-not ([string]::IsNullOrEmpty($key))) 
    {
      $object | Add-Member -Type NoteProperty -Name $key -Value $value
    }
  }

  return $objectList
}



# cluster
$cluster1c = RacOutToObject (& $cpath $cserverRAS cluster list)
$cluster_uuid = $cluster1c.cluster

# !!! вывод для отладки
$cluster1c | Format-Table


# infobases
$infobases = RacOutToObject (& $cpath $cserverRAS infobase --cluster=$cluster_uuid summary list)

# !!! вывод для отладки
$infobases | Format-Table


FOREACH ($infobase in $infobases) 
{
  if ($infobase.name -eq $bases1c) 
  {
    # создаем переменные, консоль не умеет работать с переменными массива
    $infobase_uuid = $infobase.infobase
    $infobase_name = $infobase.name
    
    Write-Host Начинаем работу с базой: $infobase_name
    $sessions = RacOutToObject(& $cpath $cserverRAS session list --cluster=$cluster_uuid --infobase=$infobase_uuid)
        
    #блокируем сеансы
    FOREACH ($session in $sessions) 
    {
      $session_uuid = $session.session
      $sessionsUsr = $session.user_name
    
      Write-Host -Object "Закрываем: $sessionsUsr сеанс в базе: $infobase_name"
      # здесь вывод всей информации о сеансе
      $session | Format-List
      # периписать на Start-Process -FilePath $cpath -ArgumentList "$cserverRAS session terminate --cluster=$cluster_uuid --session=$session_uuid"
      & $cpath $cserverRAS session terminate --cluster=$cluster_uuid --session=$session_uuid
    }    
  }  
}
