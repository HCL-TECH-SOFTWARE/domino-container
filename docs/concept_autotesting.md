---
layout: default
title: "Automation Testing"
nav_order: 7
parent: "Concept & Overview"
description: "Automation Testing"
has_children: false
---


# Introduction

Automation testing plays and important role in software development.
The community image itself can be part of your automation test infrastructure.

On the other side also the container image itself needs to be automation tested.
The `testing` directory contains an automation test script, which invokes a Domino server configured via Domino One Touch Setup (OTS) and performs automation tests to ensure the container image is functional.

The automation test can be added to the build process (`-autotest`) and is performed before the image is tagged latest or with another specific label and before the image is optionally pushed to a registry. The automation test script `AutomationTest.sh` can be also started manually on any Domino container image by specifying the image via `-image=xyz`.


# Container label for add-on software

The main labels are reflecting the Domino version.
Additional software components are added to a combined label `DominoContainer.addons` specifying all additional Domino software added.

Example: ```"DominoContainer.addons": "ontime=11.1.1,languagepack=DE,verse=3.2.0,nomad=1.0.9-14.0,traveler=14.0,domrestapi=1.0.8,capi=14.0,leap=1.1.3"```

The add-on software listed in this label is end to end validated by starting the application and querying the corresponding end points. For example for Traveler using the authenticated status query.

# Example output with add-ons installed

```
--------------------------------------------------------------------------------
 Test Results
--------------------------------------------------------------------------------

{
  "testResults": {
    "harness": "DominoCommunityImage",
    "suite": "Regression",
    "testClient": "testing.notes.lab",
    "testServer": "testing.notes.lab",
    "platform": "CentOS Stream 9",
    "platformVersion": "9 CentOS Stream",
    "hostVersion": "9 CentOS Stream",
    "hostPlatform": "CentOS Stream 9",
    "testBuild": "14.0",
    "containerPlatform": "docker",
    "containerPlatformVersion": "24.0.7",
    "kernelVersion": "5.14.0-390.el9.x86_64",
    "kernelBuildTime": "#1 SMP PREEMPT_DYNAMIC Fri Nov 24 10:44:56 UTC 2023",
    "glibcVersion": "2.34",
    "timezone": "Etc/UTC",
    "javaVersion": "17.0.8.1 2023-08-24",
    "dominoAddons": "ontime=11.1.1,languagepack=DE,verse=3.2.0,nomad=1.0.9-14.0,traveler=14.0,domrestapi=1.0.8,capi=14.0,leap=1.1.3",
    "testcase": [
      {

...

[ SUCCESS ]  addon.installed.ontime
[ SUCCESS ]  addon.installed.languagepack
[ SUCCESS ]  addon.installed.verse
[ SUCCESS ]  addon.installed.nomad
[ SUCCESS ]  addon.installed.traveler
[ SUCCESS ]  addon.installed.domrestapi
[ SUCCESS ]  addon.installed.capi
[ SUCCESS ]  addon.installed.leap
[ SUCCESS ]  domino.jvm.available
[ SUCCESS ]  domino.server.running
[ SUCCESS ]  domino.http.running
[ SUCCESS ]  domino.certificate.available
[ SUCCESS ]  domino.server.onetouch.microca-cert
[ SUCCESS ]  capi.compile&run
[ SUCCESS ]  traveler.server.available
[ SUCCESS ]  nomad.server.available
[ SUCCESS ]  verse.server.available
[ SUCCESS ]  restapi.server.available
[ SUCCESS ]  domino-leap.server.available
[ SUCCESS ]  domino-leap.server.version
[ SUCCESS ]  domino.server.onetouch.createdb
[ SUCCESS ]  domino.idvault.create
[ SUCCESS ]  domino.backup.create
[ SUCCESS ]  startscript.archivelog
[ SUCCESS ]  container.health
[ SUCCESS ]  startscript.server.restart
[ SUCCESS ]  domino.translog.create

--------------------------------------------------------------------------------

Success :  27
Error   :   0
Total   :  27
```

