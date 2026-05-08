# SCISideloadFix

SCInsta-local sideload app-group/keychain fix library.

This is derived from [`asdfzxcvbn/zxPluginsInject`](https://github.com/asdfzxcvbn/zxPluginsInject),
which is itself a rewrite of choco's original patch. It also vendors Facebook's
[`fishhook`](https://github.com/facebook/fishhook) for C symbol rebinding.

Compared with upstream `zxPluginsInject`, this variant changes app-group
container handling so `NSUserDefaults` uses the same redirected container policy
as `NSFileManager` in app-extension processes:

- retry app-group lookup until `LSBundleProxy` returns a usable group URL
- fall back to a Documents-backed group path when no app-group URL is available
- create redirected suite container directories before passing them to defaults
- leave main-app `NSUserDefaults` on its original container so Instagram's
  cold-launch UI dismissal flags can persist normally

Build with:

```sh
make -C modules/SCISideloadFix DEBUG=0 FINALPACKAGE=1
```

`build.sh sideload --patch` builds this dylib and passes it to `ipapatch --dylib`
automatically.
