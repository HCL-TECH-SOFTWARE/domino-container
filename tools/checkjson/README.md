# Check JSON Tool

This helper tool is intended to validate Domino OneToch setup JSON files against the schema provided by Domino.
It can be used to validate a JSON file, in case  no Domino is installed on the Docker host.

To ensure compatibility with the HCL validjson, the command-line tool also supports `-default` to find the default schema file in Domino binary directory.

## Syntax


```
./checkjson file.json [schema.json]
```


## Example

```
checkjson /opt/nashcom/startscript/OneTouchSetup/first_server.json /opt/hcl/domino/notes/latest/linux/dominoOneTouchSetup.schema.json

JSON file [/opt/nashcom/startscript/OneTouchSetup/first_server.json] validated according to schema [/opt/hcl/domino/notes/latest/linux/dominoOneTouchSetup.schema.json]!

```

## Retun codes


 Ret | Text |
| :------- | --- |
| 0 | JSON valid
| 1 | JSON invalid
| 2 | Not matching schema
| 3 | File error


## How to build

**checkjson** is written in C++ and requires [RapidJSON](https://rapidjson.org/) and the GNU C++ compiler.


### Install GNU C++ compiler and RapidJSON development package


RedHat and all yum based systems (you might want to replace it with `dnf` in future)

```
yum install -y gcc rapidjson-devel
```

SUSE SLES/Leap

```
zypper install -y gcc rapidjson-devel
```

### Build binary

Switch to the `tools/checkjson` directory and run make.

Known issue: Warning messages during compile, depending on compiler: `warning: jump to label 'Done' / crosses initialization`.
This has no impact on the build process. The binary builds and is fully functional.


```
make
```

### Install binary

This command installs the binary in /usr/bin for global use.
Note: If the binary is not build, this step will also build the binary.

```
make install
```

