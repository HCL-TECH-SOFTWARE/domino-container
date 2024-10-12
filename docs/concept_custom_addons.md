---
layout: default
title: "Custom Add-ons"
nav_order: 6
parent: "Concept & Overview"
description: "Custom Add-ons"
has_children: false
---

# Custom add-on build support


## Why custom add-ons for Domino containers?

Container images provide the Domino software read-only under `/opt`.
Images are designed to not allow any changes in the binary directory by design and for security reasons.
Adding software to the binary directory would need to run a "root" shell into the container.
All changes would be lost when the container is recreated.


## Adding custom software on top of Domino

The `build.sh` command provides the option to add custom add-ons by using the the option `-custom-addon=` or as the help command of the build-script describes it:

**-custom-addon=**  specify a tar file with additional Domino add-on software to install format: (https://)file.taz#sha256checksum

You can add multiple add-ons by separating the values with a comma (,).
So every add-on can be in its own tarball.

The tarball can be either placed on a web server reachable from your build machine with a http(s) link.
Or it can be loaded from the same location where all install packages were downloaded (default: /local/software).
When specifying a URL, the build-script will try to download the package from a web server, if you only specify a filename, the build-script assumes it is in the default software location.

## Structure of the tarball

There are 3 predefined directories and one predefined file for the tarball. Let me explain these from an example of a tarball’s file tree.
Additional files in the tar can be leveraged by the custom `install.sh` script.

```
├── domino-bin
│   ├── jvm
│   │   ├── conf
│   │   │   └── security
│   │   │       └── java.security
│   │   └── lib
│   │       └── security
│   │           └── cacerts
│   └── libnshsmtp.so
├── domino-data
│   └── nshsmtp
│       ├── nshsmtpconfig.ntf
│       ├── nshsmtpipcache.ntf
│       ├── nshsmtpjournal.ntf
│       └── nshsmtplog.ntf
├── install.sh
└── linux-bin
    └── nshmailx
```

### domino-bin

The domino-bin directory refers to the `/opt/hcl/domino/notes/latest/linux` directory, so any file in here will be added to or replacing a file in this directory or one of its sub-directories.
As you can see in the example above, this tarball adds the `libnshsmtp.so` as a Domino program task (this is the library for SpamGeek) and adds a custom Java security policy and `cacerts` key/certs database.

### domino-data

Any file or directory with file here will end up in your /local/notesdata directory, but only when setting up a new server with this Domino image.
As the `notesdata` directory is on a persistent volume, changes to the image won’t make any changes to an existing notesdata directory.

### linux-bin

Files in this directory are added to `/usr/bin`.
`linux-bin` is not meant for adding extra Linux packages to the container that would be installed by yum/dnf/apt-get as those would be added by using the option `-linuxpkg=` in the build.sh script.

### install.sh

`install.sh` is an optional install script that is executed during the image build process and which can be used to make changes to the image that can’t be made through the three predefined directories.
It could be used, for any custom logic for any other application requirement.

Ensure the script executing the install logic works with relatives directories.

The tar is extracted into a temporary directory and the current directory is set to the directory before `install.sh` is called.

### Creating the tarball and SHA256 hash

Once you have your files in the above structure, you can create your tarball:

```
tar -cvzf MyAddon.taz

domino-bin/
domino-bin/jvm/
domino-bin/jvm/conf/
domino-bin/jvm/conf/security/
domino-bin/jvm/conf/security/java.security
domino-bin/jvm/lib/
domino-bin/jvm/lib/security/
domino-bin/jvm/lib/security/cacerts
domino-bin/libnshsmtp.so
domino-data/
domino-data/nshsmtp/
domino-data/nshsmtp/nshsmtpjournal.ntf
domino-data/nshsmtp/nshsmtpipcache.ntf
domino-data/nshsmtp/nshsmtpconfig.ntf
domino-data/nshsmtp/nshsmtplog.ntf
install.sh
linux-bin/
linux-bin/nshmailx
```

This created a file **MyAddon.taz**. Next you get the SHA256 hash of this file:

```
sha256sum MyAddon.taz
63cceac799a5db23fe06f0fbae5de0259a7ff0ec016d7be03cb940a2d6139f36  MyAddon.taz
```

If you move your add-on file to your software download directory (default: **/local/software**), you can use it in your build command by running:

```
./build.sh -custom-addon=MyAddon.taz#63cceac799a5db23fe06f0fbae5de0259a7ff0ec016d7be03cb940a2d6139f36 menu
```

This will load the usual build menu, but you will see in the menu a line: **Add-Ons : MyAddon.taz.**  
The same option is also available for command-line installs.
