---
layout: default
title: "Domino Leap"
nav_order: 5
parent: "Concept & Overview"
description: "Domino Leap"
has_children: false
---

# Domino Leap

[HCL Domino Leap](https://www.hcl-software.com/domino/offerings/domino-leap) is a no-code capability that makes it easy to develop powerful, secure, and enterprise-grade workflow-based applications. While it runs on Domino, you don’t need any specialized Domino or IT skills.


Domino Leap used to be a separate image build on top the Domino image.
Beginning with Domino 14, it is now availabe as an build options for the standard Domino image and can be combined with other add-ons like Traveler or the REST API.

The separate add-on image build remains to be available for now.

To build an image including Domino Leap, just specify the `-leap` build option.

```
./build domino -leap
```

The build script automatically determines the latest version.
An earlier version can be specified explicitly via e.g. `--leap=1.1.2`


For details Domino Leap administration refer to the [Domino Leap documentation](https://help.hcltechsw.com/domino-leap/welcome/index.html).

