# macOSLOBAppTool
This tool is designed to manage macOS apps that cannot be distributed via MEM as a .intunemac file.
Instead of wrapping the application, the .pkg or .dmg is uploaded to an Azure storage blob and a shell script
is created in MEM. When the script runs on a mac, it curls the package from the blob and if it's a DMG, mounts
and installs or if it's a PKG, installs directly. The blob downloads to the currently logged on users Downloads folder.
After install is complete, the package is removed from Downloads.

A metadata tag is added to the blob with the format "Version: {CFBundleShortVersion}" to keep track of uploaded versions.

If 7-zip is installed on the device running this WPF, the script will try to automatically extract the CFBundleShortVersion
from the Info.plist file, it is also possible to enter the version manually.

Per default, the install location is set to /Applications. If needed this can be changed. This path is needed to detect if
the latest version of the app is already installed on the mac.

Before using, keep in mind that this is an early version of this tool. Test **thoroughly**. 

## Planned features
- Ability to assign app from the WPF
- Handle updating apps from WPF

## Pre-requisites
To use this tool you need a couple of moduels installed
- Az.Storage
- Microsoft.Graph.Authentication

Also, a storage account must already be created. Using this tool it is assumed that the container is publicly available.

## Verified Powershell versions
:white_check_mark:7.1.3

:white_check_mark:7.0.4

# Usage
```powershell: .\path\to\macoslobapptool.ps1```

# GUI
![GUI](https://user-images.githubusercontent.com/78877636/113025035-bea48e80-9187-11eb-8bce-4ac878dfe447.png)

# Screenshots
## App selection
Only apps with CFBundleShortVersion and Install Path are uploaded.
![image](https://user-images.githubusercontent.com/78877636/113021659-18a35500-9184-11eb-9a7c-3842ca39f023.png)
## Console output
![image](https://user-images.githubusercontent.com/78877636/113022000-6fa92a00-9184-11eb-8257-3509aaf64e0f.png)
## Azure blob
![image](https://user-images.githubusercontent.com/78877636/113022390-d75f7500-9184-11eb-8f2f-9dff4403213a.png)
## MEM Shell script
![image](https://user-images.githubusercontent.com/78877636/113022608-12fa3f00-9185-11eb-973e-99f7f4df46e0.png)

# Disclaimer
This code and information are provided "AS IS" without warranty of any kind, either expressed or implied. The entire risk arising out of the use or performance of the script and documentation remains with you. Furthermore, the author shall not be liable for any damages you may sustain by using this information, whether direct, indirect, special, incidental or consequential, including, without limitation, damages for loss of business profits, business interruption, loss of business information or other pecuniary loss even if it has been advised of the possibility of such damages. Read all the implementation and usage notes thoroughly.
