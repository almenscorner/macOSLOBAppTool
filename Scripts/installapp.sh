#!/bin/bash

# exit when any command fails
set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command failed with exit code $?."' EXIT

baseURL=""
container=""
packageName=""
CFBundleShortVersion=""
installLocation=""
sasToken="?sp=r&st=2021-03-29T10:15:42Z&se=2021-03-31T18:15:42Z&spr=https&sv=2020-02-10&sr=c&sig=XE5%2BbP0JJzo8rFwePOqsERznYMmaw0WqIG9y7A3aHhk%3D"
shortName=$(echo $packageName | cut -c1-5)
WORKDIR=/tmp/${packageName}
[ ! -f ${WORKDIR} ] || /bin/rm -rf ${WORKDIR}
#mkdir -p ${WORKDIR} cd ${WORKDIR}
shopt -s nocaseglob

#Check if application is already installed
if [[ `ls -l $installLocation/$shortName*.app` ]]; then

	installedVersion=$(defaults read $installLocation/$shortName*.app/Contents/info.plist CFBundleShortVersionString)

	if [[ $installedVersion == $CFBundleShortVersion ]]; then
		echo "Latest version already installed"
	fi

	else
		echo "Downloading ${packageName}"
		curl -X GET -H "x-ms-date: $(date -u)" "${baseURL}/${container}/${packageName}${sasToken}" --output ${WORKDIR}
		
		echo "Installing ${packageName}"

		#If package is a DMG-file, mount and install
		if [[ $packageName == *.dmg ]]; then
			#Mount DMG
			sudo hdiutil attach ${WORKDIR} -noverify -nobrowse -noautoopen
			
			#If .app, copy the app to /Applications
			if [[ `ls -l /Volumes/$shortName*/*.app` ]]; then
				echo "Copying app to Applications"
				sudo cp -R /Volumes/$shortName*/*.app /Applications
			
			#If .PKG, install the app
			elif [[ `ls -l /Volumes/$shortName*/*.pkg` ]]; then
				echo "Installing PKG"
				sudo installer -package /Volumes/$shortName*/*.pkg -target "/Volumes/Macintosh HD"
			else
				echo "Unable to find .PKG or .app for package $packageName"
			fi
			#Unmount DMG
			hdiutil unmount /Volumes/$shortName*
			echo "$packageName successfully installed"
		fi
		
		#If package is a PKG-file, install the package
		
		if [[ $packageName == *.pkg ]]; then
			sudo installer -package "${WORKDIR}/${packageName}.pkg" -target "/Volumes/Macintosh HD"
		fi
		
		rm -rf ${WORKDIR}
	
fi