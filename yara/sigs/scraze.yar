rule Scraze
{
  strings:
    $strval1 = "C:\Windows\ScreenBlazeUpgrader.bat"
    $strval2 = "\ScreenBlaze.exe "
  condition:
    all of them
}