# Code by MSP-Greg

# $OutputEncoding = New-Object -typename System.Text.UTF8Encoding

if ($env:APPVEYOR) {
  New-Variable -Name base_path -Option ReadOnly, AllScope -Scope Script -Value `
    'C:/Program Files/7-Zip;C:/Program Files/AppVeyor/BuildAgent;C:/Program Files/Git/cmd;C:/Windows/system32;C:/Windows;C:/Program Files (x86)/GNU/GnuPG/pub;C:/WINDOWS/System32/OpenSSH;'
  New-Variable -Name dir_ruby  -Option ReadOnly, AllScope -Scope Script -Value 'C:\Ruby'
  New-Variable -Name dir_msys2 -Option ReadOnly, AllScope -Scope Script -Value 'C:\msys64'
  New-Variable -Name fc        -Option ReadOnly, AllScope -Scope Script -Value 'Yellow'

  New-Variable -Name enc       -Option AllScope -Scope Script

} else {
  . .\local_paths.ps1
}

Write-Host "`nimage: $env:APPVEYOR_BUILD_WORKER_IMAGE" -ForegroundColor $fc

$enc = [Console]::OutputEncoding.HeaderName

New-Variable -Name dash -Option ReadOnly, AllScope -Scope Script -Value "$([char]0x2015)"

[string[]]$sufs = '', '-x64'
[string[]]$rubies  = '193', '200', '21', '22', '23', '24', '25', '26', '27', '_trunk'

$dt = $(Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")

Write-Host ""
Write-Host " $dt  MSYS2 / MinGW".PadLeft(103, $dash) -ForegroundColor $fc

# Set Path to Ruby 25 64 & MSYS Info
$env:path  = $dir_ruby + "25-x64\bin;$env:USERPROFILE\.gem\ruby\2.5.0\bin;"
$env:path += "$base_path$dir_msys2\usr\bin"

ruby.exe pacman_query.rb $enc

Write-Host "`n$($dash * 102)" -ForegroundColor $fc

foreach ($ruby in $rubies) {
  foreach ($suf in $sufs) {
    if ($ruby -ne '_trunk') {
      if( !( Test-Path -Path $dir_ruby$ruby$suf ) ) { continue }
      $ruby_vers = $ruby.Substring(0,1) + '.' + $ruby.Substring(1,1) + '.0'
      $env:path  = "$dir_ruby$ruby$suf\bin;$env:USERPROFILE\.gem\ruby\$ruby_vers\bin;"
      $env:path += $base_path
    } elseif (($suf -eq '-x64') -and ($env:APPVEYOR)) {
      $trunk_uri = 'https://ci.appveyor.com/api/projects/MSP-Greg/ruby-loco/artifacts/ruby_trunk.7z'
      (New-Object Net.WebClient).DownloadFile($trunk_uri, 'C:\ruby_trunk.7z')
      7z.exe x C:\ruby_trunk.7z -oC:\Ruby_trunk 1> $null
      $env:path  = "C:\Ruby_trunk\bin;$env:USERPROFILE\.gem\ruby\2.6.0\bin;"
      $env:path += $base_path
    } else { continue }

    $dt = $(Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")
    $rv = (&ruby.exe -e "puts RUBY_VERSION" | Out-String).Trim()

    # Finally, run Ruby Info, Ruby193 has a warning for psych
    Write-Host
    Write-Host " $dt  Ruby $rv$suf".PadLeft(102, $dash) -ForegroundColor $fc
    ruby.exe ./ruby_info.rb $enc
    Write-Host "`n$($dash * 102)" -ForegroundColor $fc
  }
}

Write-Host "`nimage: $env:APPVEYOR_BUILD_WORKER_IMAGE" -ForegroundColor $fc

Write-Host "`n$($dash * 8) Encoding $($dash * 8)" -ForegroundColor $fc
Write-Host "PS Console  $enc"
Write-Host "PS Output   $($OutputEncoding.HeaderName)"
iex "ruby.exe -e `"['external','filesystem','internal','locale'].each { |e| puts e.ljust(12) + Encoding.find(e).to_s }`""
Write-Host ''
