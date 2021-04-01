# macOSLOBAppTool
**Background**

This tool is designed to manage macOS apps that cannot be distributed via MEM when wrapped as an .intunemac file. There are a number of limitations using the wrapping method, some of them being that only .pkg files are supported and that we have to rely on the MDM framework in macOS to detect the app. Only apps installed to /Applications can be detected with this method and the app must have a very sepcific structure to be detected. If the app does not include specific parameters your only option is to ask the developer to change this.

If you have a .dmg package you would like to publish in MEM, you would have to convert this to a .pkg. When doing this you must have a Apple Developer certificate to sign your converted app.

**Solution**

With the above limitations in mind I decided to build a tool which can deploy virtually any app using the Microsoft Intune Agent to run scripts and Azure Storage Account to build a app repository.

When running the tool, the app won't be wrapped but instead uploads to an Azure blob and a macOS shell script is created in MEM. When the script runs on a mac, it curls the package from the blob and if it's a DMG, mounts and installs or if it's a PKG, installs directly. The blob downloads to the currently logged on users Downloads folder. After the installation is complete, the package is removed from Downloads.

A metadata tag is added to the blob with the format "Version: {CFBundleShortVersion}" to keep track of uploaded versions.

If 7-zip is installed on the device running this tool, the script will try to automatically extract the CFBundleShortVersion
from the Info.plist file, it is also possible to enter the version manually.

Per default, the install location is set to /Applications. If needed this can be changed. This path and CFBundleShortVersion is needed to detect if
the latest version of the app is already installed on the mac.

Before using, keep in mind that this is an early version of this tool. Test **thoroughly**.

- [Planned features](#planned-features)
- [Pre-requisites](#pre-requisites)
- [Powershell versions](#powershell-versions)
- [Usage](#usage)
- [GUI](#gui)
- [Screenshots](#screenshots)
  * [App selection](#app-selection)
  * [Console output](#console-output)
  * [Azure blob](#azure-blob)
  * [MEM Shell script](#mem-shell-script)
- [Limitations](#limitations)
- [Changelog](#changelog)

## Planned features
- ~~Ability to assign app from the WPF~~
- Handle updating apps from WPF
- ~~Get CFBundleShortVersion from .pkg packages using 7-zip~~

## Pre-requisites
To use this tool you need a couple of moduels installed
- Az.Storage
- Microsoft.Graph.Authentication

Also, a storage account must already be created. Using this tool it is assumed that the container is publicly available.

## Powershell versions
:white_check_mark: 7.1.3

:white_check_mark: 7.0.4

:x: 5.X

## Usage
Before use, you might have to unblock the files.

Launch the script by typing:
```.\path\to\macoslobapptool.ps1```

## GUI
![GUI](https://user-images.githubusercontent.com/78877636/113025035-bea48e80-9187-11eb-8bce-4ac878dfe447.png)

## Screenshots
### App selection
Only apps with CFBundleShortVersion and Install Path are uploaded.
![image](https://user-images.githubusercontent.com/78877636/113021659-18a35500-9184-11eb-9a7c-3842ca39f023.png)
### Console output
![image](https://user-images.githubusercontent.com/78877636/113022000-6fa92a00-9184-11eb-8257-3509aaf64e0f.png)
### Azure blob
![image](https://user-images.githubusercontent.com/78877636/113022390-d75f7500-9184-11eb-8f2f-9dff4403213a.png)
### MEM Shell script
![image](https://user-images.githubusercontent.com/78877636/113022608-12fa3f00-9185-11eb-973e-99f7f4df46e0.png)

## Limitations
- DMGs that contains an installer.app is not supported. Have not figured out how an install of these types of installers would work from a script.

## Changelog
**Version 1.04.01.01 2021-04-01**
- Added function to assign packages
- The tool now tries to extract CFBundleShortVersion from .PKGs
- Removed the dependecy of 7z.exe in script folder, it now snags the path to the EXE from registry
- Added button to GitHub repo to the top
- Added twitter icon with @handle to the top

**Version 1.03.31.01 2021-03-31**
- Removed script frequency, the script now only executes **one** time on devices

**Version 1.0 2021-03-30**
- Initial release
