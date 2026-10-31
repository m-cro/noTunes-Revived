# noTunes Revived

A menu bar app that stops Apple Music from launching when you press play/pause on your earbuds or media keys.

macOS routes those presses through `mediaremoted`, which launches Music when no app is the "Now Playing" app. noTunes Revived fills that role while nothing else is playing: it registers as a Now Playing client with a silent audio loop and swallows the command. As soon as any other app (Spotify, a browser, ...) registers as a Now Playing client, it steps aside so the press goes straight to that app. As a fallback it also quits Music if it launches anyway.

Other clients are detected by watching `mediaremoted`'s log (`/usr/bin/log stream`), which is not an official API and may break with macOS updates.

## Build

```sh
./build.sh           # builds noTunesRevived.app
./build.sh install   # also copies to ~/Applications and adds a login item
```

## Menu

- **Blocking Music** – toggle blocking on/off
- **Show Menu Bar Icon** – hide the tray icon; open the app again to bring it back

## Credits

App and menu bar icons are from [noTunes](https://github.com/tombonez/noTunes) by tombonez (MIT).
