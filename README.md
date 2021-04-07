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
- Add a dark theme switch. Why you ask? Because it's fun

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

## Screenshots
### Light/Dark mode
![mlatnewlight](https://user-images.githubusercontent.com/78877636/113880302-a9e57d80-97bb-11eb-9874-b5c690aff774.png)![mlatnewdark](https://user-images.githubusercontent.com/78877636/113880345-b4a01280-97bb-11eb-87bb-3ce2f1c2b828.png)
![mlatupdatebadgelight](https://user-images.githubusercontent.com/78877636/113880666-f92bae00-97bb-11eb-98bc-e38d6f69e789.png)![mlatupdatedark](https://user-images.githubusercontent.com/78877636/113880700-fdf06200-97bb-11eb-9ee2-069902bc6dcf.png)
### Badges
![mlatuploadbadge](https://user-images.githubusercontent.com/78877636/113881134-6fc8ab80-97bc-11eb-884d-64b36469337a.png)![mlatupdatebadge](https://user-images.githubusercontent.com/78877636/113881148-748d5f80-97bc-11eb-9c4d-44e988ecd375.png)
### Warning popup
![mlatwarning](https://user-images.githubusercontent.com/78877636/113881202-840ca880-97bc-11eb-8ec5-db85c69d4c76.png)
### Console output
![mlatconsole](https://user-images.githubusercontent.com/78877636/113880740-0779ca00-97bc-11eb-9c2d-da0a71d53563.png)
### Azure blob
![image](https://user-images.githubusercontent.com/78877636/113022390-d75f7500-9184-11eb-8f2f-9dff4403213a.png)
### MEM Shell script
![image](https://user-images.githubusercontent.com/78877636/113022608-12fa3f00-9185-11eb-973e-99f7f4df46e0.png)

## Limitations
- DMGs that contains an installer.app is not supported. Have not figured out how an install of these types of installers would work from a script.

## Changelog
**Version 1.04.07.01 2021-04-07**
- Added update functionality
- Added button badges when uploading/updating
- New tabbed interface for uploading new packages and updating
- Added popup messages for warnings (thanks [smsagent](https://smsagent.wordpress.com/2017/08/24/a-customisable-wpf-messagebox-for-powershell/))
- Renamed Themes folder to Assembly
- Added material icons and removed Octions
- Updated shell script for installing apps to handle versions in format of X.X.X
- Added dark theme switch, now you can upload/update in style 😎

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
