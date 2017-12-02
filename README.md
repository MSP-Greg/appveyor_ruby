This repo contains an Appveyor script and two ruby script files.  Its only purpose is to report information about the Ruby builds on Appveyor from 2.1 forward.

The most recent build is at [ci.appveyor.com/project/MSP-Greg/appveyor-ruby](https://ci.appveyor.com/project/MSP-Greg/appveyor-ruby).  The top of the Appveyor log shows the installed MinGW packages, then the MSYS2 packages.  After that is information on Ruby 2.1 thru 2.4, and trunk.

The trunk build is available on [Appveyor](https://ci.appveyor.com/project/MSP-Greg/ruby-loco/history).

If you're interested in adding a ruby trunk build to your appveyor script, the following in the the script/yaml file should install it (assumes your environment is using 'ruby_version' such as `200`, `23`, or `24-x64`):

```yaml
init:
  - set PATH=C:\ruby%ruby_version%\bin;C:\msys64\usr\bin;C:\Program Files\7-Zip;C:\Program Files\AppVeyor\BuildAgent;C:\Program Files\Git\cmd;C:\Windows\system32
  - if %ruby_version%==_trunk (
        appveyor DownloadFile https://ci.appveyor.com/api/projects/MSP-Greg/ruby-loco/artifacts/ruby_trunk.7z -FileName C:/ruby_trunk.7z &
        7z x C:\ruby_trunk.7z -oC:\ruby_trunk
    )
```

Add the following to your environment:

```yaml
environment:
  matrix:
    - ruby_version: "_trunk"
```

The trunk build is stand-alone, but uses newer packages for OpenSSL & GDBM.  If you need to install the OpenSSL or GDBM packages for building/compiling, change the last line of the above init script to:

```yaml
        7z x C:\ruby_trunk.7z -oC:\ruby_trunk & trunk_pkgs.cmd
```

If you want to check for compiler updates and install the packages, change to:

```yaml
        7z x C:\ruby_trunk.7z -oC:\ruby_trunk & trunk_msys2.cmd
```

An example using trunk is at https://github.com/rubygems/rubygems/blob/master/appveyor.yml.