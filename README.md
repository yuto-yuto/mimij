# kikimasu

An Audio Player.

## Features

* Start/Stop/Resume
* AB loop
* Having audio List (Grouping)

## Requiredment for Linux

This application uses [AudioPlayers](https://github.com/bluefireteam/audioplayers) that requires some dependencies. Please see the [requirements](https://github.com/bluefireteam/audioplayers/blob/main/packages/audioplayers_linux/requirements.md).

## When a Permission error occurs

You might face the following permission error

```shell
$ flutter run -d linux
Launching lib/main.dart on Linux in debug mode...
CMake Error at cmake_install.cmake:66 (file):
  file INSTALL cannot copy file
  "/home/development/kikimasu/build/linux/x64/debug/intermediates_do_not_run/kikimasu"
  to "/usr/local/kikimasu": Permission denied.


Building Linux application...                                           
Exception: Build process failed
```

Run `flutter clean` in this case.

```shell
flutter clean
flutter run -d linux
```