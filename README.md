# macOSLOBAppTool
**Background**

This tool is designed to manage macOS apps that cannot be distributed via MEM when wrapped as an .intunemac file. There are a number of limitations using the wrapping method, some of them being that only .pkg files are supported and that we have to rely on the MDM framework in macOS to detect the app. Only apps installed to /Applications can be detected with this method and the app must have a very sepcific structure to be detected. If the app does not include specific parameters your only option is to ask the developer to change this.

If you have a .dmg package you would like to publish in MEM, you would have to convert this to a .pkg. When doing this you must have a Apple Developer certificate to sign your converted app.

**Solution**

With the above limitations in mind I decided to build a tool which can deploy virtually any app using the Microsoft Intune Agent to run scripts and Azure Storage Account to build a app repository.

When running the tool, the app won't be wrapped but instead uploads to an Azure blob and a macOS shell script is created in MEM. The tool now uses Microsoft's shell script for installing applications, this update introduces huge improvements to logging and update functionality.

Using this version, 7-Zip will be required to be installed since it will try to grab the CFBundleName from the Info.plist, if it fails, the package will be skipped.

The CFBundleName will be used to create strings which will be added to the install script. Note that it will use the CFBundleName to create the "processpath" variable string which is used to terminate the process when updating if you choose to do so. Some applications does not use the same name for the process, for example Firefox CFBundleName is "Firefox", but the process path is /Applications/Firefox.app/Contents/MacOS/firefox with lower case. Default will be /Applications but your app might have another path. It's important to review and update the apps info in the grid.

For guidance on what the parameters used means, see [this link](https://techcommunity.microsoft.com/t5/intune-customer-success/deploying-macos-apps-with-the-intune-scripting-agent/ba-p/2298072).

Before using, keep in mind that this is an early version of this tool. Test **thoroughly**.

- [Planned features](#planned-features)
- [Pre-requisites](#pre-requisites)
- [Powershell versions](#powershell-versions)
- [Usage](#usage)
- [Screenshots](#screenshots)
  * [App selection](#app-selection)
  * [Console output](#console-output)
  * [Azure blob](#azure-blob)
  * [MEM Shell script](#mem-shell-script)
- [Changelog](#changelog)

## Planned features
- ~~Change install script to Microsoft's shell script for enhanced logging and functionality~~
- ~~Ability to assign app from the WPF~~
- ~~Handle updating apps from WPF~~
- ~~Get CFBundleShortVersion from .pkg packages using 7-zip~~
- ~~Add a dark theme switch. Why you ask? Because it's fun~~

## Pre-requisites
To use this tool you need a couple of moduels installed
- Az.Storage
- Microsoft.Graph.Authentication
- 7-Zip

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
![newLight](https://user-images.githubusercontent.com/78877636/133284016-522960c3-497d-486c-aad8-0f52b74c7456.png)
![newDark](https://user-images.githubusercontent.com/78877636/133284081-ae445911-6797-484e-88bf-4fcea781b24a.png)
![updateLight](https://user-images.githubusercontent.com/78877636/133284119-0c394809-e1e4-41b4-830e-55d60babe887.png)
![updateDark](https://user-images.githubusercontent.com/78877636/133284131-35aa5a32-f9df-47fe-8ffb-7387d18291cf.png)
### Badges
![mlatuploadbadge](https://user-images.githubusercontent.com/78877636/113881134-6fc8ab80-97bc-11eb-884d-64b36469337a.png)
![mlatupdatebadge](https://user-images.githubusercontent.com/78877636/113881148-748d5f80-97bc-11eb-9c4d-44e988ecd375.png)
### Warning popup
![mlatwarning](https://user-images.githubusercontent.com/78877636/113881202-840ca880-97bc-11eb-8ec5-db85c69d4c76.png)
### Console output
![consoleOutput](https://user-images.githubusercontent.com/78877636/133284201-9da8468f-8ea2-4ff7-9ad5-d491a7a9aef5.png)

If more than one storage account exists, you will be asked to pick one to create a new storage context
![stSelection](https://user-images.githubusercontent.com/78877636/133284280-5d1175b3-5e7b-404e-aa24-10dd366f530b.png)
### Azure blob
![image](https://user-images.githubusercontent.com/78877636/113022390-d75f7500-9184-11eb-8f2f-9dff4403213a.png)
### MEM Shell script
![memScript](https://user-images.githubusercontent.com/78877636/133284333-30152e5d-461e-4083-857d-ee9f662e75ce.png)

## Changelog
**Version 2.0 2021-09-14**
- Install script changed to Microsoft's shell script
- When updating, the script that already exists for the app will be updated in MEM, i.e. it won't be unassigned or deleted
- Removed "unassign" button from Update tab
- Changed grid columns to align with Microsoft's shell script
- Check to see if more than one storage accounts is returned

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
