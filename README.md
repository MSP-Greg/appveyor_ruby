This repo contains an Appveyor script and two ruby script files.  Its only purpose is to report information about the Ruby builds on Appveyor from 2.1 forward.

The most recent build is at [ci.appveyor.com/project/MSP-Greg/appveyor_ruby](https://ci.appveyor.com/project/MSP-Greg/appveyor_ruby).  The top of the Appveyor log shows the installed MSYS2/MinGW packages, after that is information on Ruby 2.1 thru 2.4, and trunk.

The trunk build is my build (available at [BinTray](https://dl.bintray.com/msp-greg/ruby_windows/)), along with three MinGW packages, one of which is the current OpenSSL release.

If you're interested in adding a ruby trunk build to your appveyor script, the following in the the script/yaml file should install it:

```yaml
init:
  - set PATH=C:\ruby%ruby_version%\bin;C:\msys64\usr\bin;C:\Program Files\7-Zip;C:\Program Files\AppVeyor\BuildAgent;C:\Program Files\Git\cmd;C:\Windows\system32
  - if %ruby_version%==_trunk (
        appveyor DownloadFile http://dl.bintray.com/msp-greg/ruby_windows/ruby_trunk.7z -FileName C:\ruby_trunk.7z &
        7z x C:\ruby_trunk.7z -oC:\ruby_trunk & C:\ruby_trunk\trunk_install.cmd)
```

Add the following to your environment:

```yaml
environment:
  matrix:
    - ruby_version: "_trunk"
```

I expect to be updating the trunk file several times a week, and will update BinTray with it and the log files from the build & test.  Whatever is the most recent log file (`z_logs_YYYY_MM_DD_SNV.7z`) is the version of ruby contained in `ruby_trunk.7z`.  All code 7z files are signed.
