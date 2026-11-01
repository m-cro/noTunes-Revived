noTunes Revived helps you prevent Apple Music from opening when you don't want it (on newer versions of MacOS). The [original noTunes](https://github.com/tombonez/noTunes.git) just kills iTunes and Apple Music AFTER a launch, and the original noTunes implementation doesn't seem to work on modern versions of MacOS. noTunes Revived, on the other hand, registers itself as a "Now-Playing" consumer/client if no other media player is registered.

## Build
```sh
./build.sh           # builds noTunesRevived.app
./build.sh install   # also copies to ~/Applications and adds a login item
```

## Menu
- **Blocking Music** – toggle blocking on/off
- **Show Menu Bar Icon** – hide the tray icon; open the app again to bring it back
- **Only When Bluetooth Audio Connected** – only claim the media keys while a Bluetooth audio output (headphones, speaker, etc.) is connected; otherwise the app stops registering as a Now Playing client (Music is still force-quit if it launches)
<img width="226" height="126" alt="image" src="https://github.com/user-attachments/assets/6ed31192-c4e4-4ae0-81ff-5188e98d2ac6" />

## Credits
App and menu bar icons are from [noTunes](https://github.com/tombonez/noTunes) by tombonez (MIT)
