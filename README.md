# macOSLOBAppTool
This tool is designed to manage macOS apps that cannot be distributed via MEM as a .intunemac file.
Instead of wrapping the application, the .pkg or .dmg is uploaded to an Azure storage blob and a shell script
is created in MEM. When the script runs on a mac, it curls the package from the blob and if it's a DMG, mounts
and installs or if it's a PKG, installs directly.

A metadata tag is added to the blob with the format "Version: {CFBundleShortVersion}" to keep track of uploaded versions.

If 7-zip is installed on the device running this WPF, the script will try to automatically extract the CFBundleShortVersion
from the Info.plist file, it is also possible to enter the version manually.

Per default, the install location is set to /Applications. If needed this can be changed. This path is needed to detect if
the latest version of the app is already installed on the mac.

## Pre-requisites
To use this tool you need a couple of moduels installed
-Az.Storage
-Microsoft.Graph.Authentication

Also, a storage account must already be created. Using this tool it is assumed that the container is publicly available.

## Verified Powershell versions
:white_check_mark:7.1.3

:white_check_mark:7.0.4
