---
layout: default
title: "Build with locale and timezone support"
nav_order: 5
description: "Build with locale and timezone support"
parent: "Howto"
has_children: false
---

# Introduction

The Domino container project uses **UTC** and **English** as the default.  

UTC is a good choice for a container environment running in an international deployment.  
But if running in a single timezone or application servers the local timezone makes more sense.  
Therefore the Domino Container Community image has full timezone support at build time.

Changing the locale of the Domino server requires to have the right glibc language installed.  
Adding a glibc locale is a build time requirement. Therefore the community image supports to add glibc languages (locales) during build time.


# Timezone Support

- The shipping HCL Domino Container is configured with UTC timezone
- The HCL Domino container community project by default uses the timezone of the build host

The timezone can be changed using the `-tz=` build option.

Example:

```
./build.sh domino -tz=Europe/Berlin
```


## Just setting the TZ Variable is not sufficient!

Just setting the `TZ` variable does not fully switch the timezone.  
Specially with Java applications the full timezone information is required.

The timezone information is located in `/etc/localtime`.
Setting up the timezone in the container adds `tzdata` into the container and creates a symbolic link to the right timezone.

```
ln -sf "/usr/share/zoneinfo/Europe/Berlin" /etc/localtime
```

A container configuration should not be modified at run-time.  
But if the container image was built using a different timezone, timezone data for a different timezone can be mounted into the container from the host.

Example:

```
-v /etc/localtime:/usr/share/zoneinfo/Europe/Berlin
```


## How to check Domino timezone settings

To check the timezone settings use the `show timezone` Domino console command

```
show timezone
Standard Time: GMT+1:00
DST:           Observed
DST Begin:     Month[ 3] Week[-1] Weekday[Sunday]
DST End:       Month[10] Week[-1] Weekday[Sunday]
```


# Locale support

A glibc locale can be added by specifying the language.
The locale must be installed at build time to set the locale for your Domino server.

Specify the `-lang=` build option to add the glibc language support needed for your locale.

Example:

```
./build.sh domino -lang=de
```

## Additional packages installed

For most distributions glibc languages are available as separate package.
The default container base image Redhat UBI does not provide separate locales.
If any additional language is installed the `glibc-all-langpacks` package is installed.
A package for one language is usually around 22 MB. The `glibc-all-langpacks` is around 220 MB.


## Setting the locale

Once the locale is part of the image, the container can be started with the locale specified.  
Either specify the Linux language variable `LANG=` or the Domino specific locale for Domino only `DOMINO_LANG=`

```
DOMINO_LANG=de_DE.UTF-8
```


## How to check Domino locale settings

To check the locale settings use the `show locale` Domino console command

```
show locale
Region:    de [German]
Collation: de [German]
CSID:      AB(Hex)
```


# Reference: Container Build Options Locale and Language

```
-tz=<timezone>   explictly set container timezone during build. by default Linux TZ is used
-lang=<lang>     specify Linux glibc language pack to install (e.g. de,it,fr). Multiple languages separated by comma
```


# Testing an image for Locale Support

The container image automation test contains a C-API test program which can also be used to dump Domino international settings.

```
nshver -intl
```


## Example LANG=en_US.UTF-8

```
IntlFormat.Flags : 298
CURRENCY_SPACE
CLOCK_24_HOUR
DATE_MDY
DATE_4DIGIT_YEAR
CurrencyDigits : 2
Length         : 140
TimeZone       : 0
AMString       : [AM]
PMString       : [PM]
CurrencyString : [$]
ThousandString : [,]
DecimalString  : [.]
DateString     : [/]
TimeString     : [:]
YesterdayString: [Yesterday]
TodayString    : [Today]
TomorrowString : [Tomorrow]
```


## Example LANG=de_DE.UTF-8

```
IntlFormat.Flags : 331
CURRENCY_SUFFIX
CURRENCY_SPACE
CLOCK_24_HOUR
DATE_DMY
DATE_4DIGIT_YEAR
CurrencyDigits : 2
Length         : 140
TimeZone       : 0
AMString       : [AM]
PMString       : [PM]
CurrencyString : [€]
ThousandString : [.]
DecimalString  : [,]
DateString     : [.]
TimeString     : [:]
YesterdayString: [Gestern]
TodayString    : [Heute]
TomorrowString : [Morgen]
```
