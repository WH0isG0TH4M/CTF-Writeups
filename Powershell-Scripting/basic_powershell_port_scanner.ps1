# This was my first PowerShell script.
# This is a simple port scanner using Test-NetConnection.
# Note: This is not an advanced or optimized scanner.

$target = "127.0.0.1" #Change this To target ip
$ports = 1..1024 #Port scan 1 - 1024

foreach($port in $ports){
  $connection = Test-NetConnection -ComputerName $target -Port $port -WarningAction SilentlyContinue

  if($connection.TcpTestSucceeded){
  echo "Open port: $port"
  }
}
