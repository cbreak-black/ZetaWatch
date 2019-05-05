ZetaWatch
=========

![ZetaWatch displaying pool status and filesystems][ZFSImage]

ZetaWatch is a small OS X program that displays the zfs status in the menu bar, similar to
what iStat Menus does for other information. It is far from finished, and due to the
current state of libzfs and libzfs_core, changes will be required until the API
stabilizes.

I started working on it over three years ago. Originally, all it did was show the status
of the pools, without any way to interact with ZFS. It visualizes pool layout, pool status
and sends a Mac OS notification if pool corruption is detected.

Last year I added some minimal interactivity features, first via running the command line
tools, and later rewritten using the zfs library. This was mainly driven by the need to
manually enter the password and mount datasets for encrypted ZFS. Currently supported
features are:

 * Show pool and vdev status including scrub progress
 * Report errors in notification center
 * Import pools
 * Mount / unmount datasets
 * Load encryption keys for encrypted datasets


Installation
------------

ZetaWatch does not require manual installation. The bundled helper tool gets installed
automatically the first time a privileged operation is performed. This requires user-
authentication. The helper tool is updated as needed.


For Developers
==============

ZFS Interaction
---------------

ZetaWatch communicates with zfs using `libzfs.dylib`, `libzfs_core.dylib` ,
`libzpool.dylib` and `libnvpair.dylib`, just like the command line tools do. This gives
it all the flexibility of the command line tools, at the cost of having to reimplement
functionality that is found in the tools and not the library. And since the libraries are
explicitly not meant to provide a stable ABI, ZetaWatch is also closely coupled to the
ZFS version it is built and written for.

All the ZFS interaction is wrapped in the ZFSWrapper library. This C++ library isolates
the issues mentioned above and provides a more convenient and safe API than the original
C interface does. The library is used both by the helper tool and the frontend app. This
is the most reusable part of ZetaWatch, and might be split out as separate project later.

 * *ZFSUtils* contains most of the advanced functionality, such as C++ Wrappers around the
library, pool, vdev or file system handles. Those classes also have functionality to query
state and iterate over members.
 * *ZFSNVList* provides a wrapper around the `nvpair_t` / `nvlist_t` data structure that
is used in ZFS for a lot of userland / kernel communication. It manages resources in both
owning and non-owning fashion, and allows for easier iteration over sequences.
 * *ZFSStrings* translate ZFS status enums into the user facing emoji or string
description, optionally with localization. (Localization is not well tested or supported
at the moment.)


Helper Tool
-----------

The implementation of the helper tool follows apple's [EvenBetterAuthorizationSample].

The helper tool communicates with the user application via `AuthorizationService` and
`NSXPCConnection`. The application side of code for this is in `ZetaAuthorization.m`. The
RPC protocol can be found in `ZetaAuthorizationHelperProtocol.h`, and is implemented in
`ZetaAuthorizationHelper.mm`. The `CommonAuthorization.m` file contains the supported
commands and associated default permissions.

The helper tool can be uninstalled with the `uninstall-helper.sh` script. This is useful
for debugging the installation of the helper, or updating the helper without increasing
the bundle version.


Security & Code Signing
-----------------------

Official release builds are signed and notarized, and should run without issues even on
newer Mac OS X. But there are still issues with authentication reported with the program
not being recognized as signed. To verify security manually, the following commands can
be used:

```bash
codesign -v -v -d ZetaWatch.app
xcrun stapler validate -v ZetaWatch.app
```

Building ZetaWatch requires an apple developer account with DeveloperID signing
capabilities, since it uses [`SMJobBless`] to run a helper service as root. This service
executes actions on behalf of the user, such as mounting, unmounting or loading a key.
[Notarization] is required to create binaries that can be run without without warning on
the newest Mac OS X.


License
=======

This program is copyrighted by me, because I wrote it.
This program is licensed under the "3-clause BSD" License. See the BSD.LICENSE.md file for
details.

[EvenBetterAuthorizationSample]: https://developer.apple.com/library/content/samplecode/EvenBetterAuthorizationSample/Introduction/Intro.html
[`SMJobBless`]: https://developer.apple.com/documentation/servicemanagement/1431078-smjobbless?language=objc
[Notarization]: https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution?language=objc
[ZFSImage]: https://raw.githubusercontent.com/cbreak-black/ZetaWatch/master/doc/ZetaWatch.jpg
