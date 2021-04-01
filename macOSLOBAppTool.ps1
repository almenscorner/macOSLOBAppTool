<#
    .SYNOPSIS
        WPF GUI tool to manage macOS LOB apps in MEM.
        Created by: Tobias Almen
    
    .DESCRIPTION
        This tool is designed to manage macOS apps that cannot be distributed via MEM as a .intunemac file.
        Instead of wrapping the application, the .pkg or .dmg is uploaded to an Azure storage blob and a shell script
        is created in MEM. When the script runs on a mac, it curls the package from the blob and if it's a DMG, mounts
        and installs or if it's a PKG, installs directly.
        A metadata tag is added to the blob with the format "Version: {CFBundleShortVersion}" to keep track of uploaded versions.
        If 7-zip is installed on the device running this WPF the script will try to automatically extract the CFBundleShortVersion
        from the Info.plist file, it is also possible to enter the version manually.
        Per default, the install location is set to /Applications. If needed this can be changed. This path is needed to detect if
        the latest version of the app is already installed on the mac.
        It's assumed that the container on the storage account is publicly available.
    .LINK
        https://github.com/almenscorner/macOSLOBAppTool
#>  

#===========================================================================
# Add assemblies
#===========================================================================
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$AssemblyLocation = Join-Path -Path $ScriptPath -ChildPath .\Themes
foreach ($Assembly in (Dir $AssemblyLocation -Filter *.dll)) {
     [System.Reflection.Assembly]::LoadFrom($Assembly.fullName) | out-null
}

#===========================================================================
# XAML
#===========================================================================
$inputXML = @"
<mah:MetroWindow
        
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    xmlns:mah="http://metro.mahapps.com/winfx/xaml/controls"
    xmlns:iconPacks="http://metro.mahapps.com/winfx/xaml/iconpacks"
    WindowStartupLocation="CenterScreen"
    mc:Ignorable="d"
    Title="macOS LOB App Tool" Height="450" Width="800">

    <Window.Resources>
        <ResourceDictionary>
          <ResourceDictionary.MergedDictionaries>
            <!-- MahApps.Metro resource dictionaries. Make sure that all file names are Case Sensitive! -->
            <ResourceDictionary Source="pack://application:,,,/MahApps.Metro;component/Styles/Controls.xaml" />
            <ResourceDictionary Source="pack://application:,,,/MahApps.Metro;component/Styles/Fonts.xaml" />
            <!-- Theme setting -->
            <ResourceDictionary Source="pack://application:,,,/MahApps.Metro;component/Styles/Themes/Light.Blue.xaml" />
          </ResourceDictionary.MergedDictionaries>
        </ResourceDictionary>
    </Window.Resources>
    <mah:MetroWindow.LeftWindowCommands>
    <mah:WindowCommands>
       <Button Name="Github" ToolTip="Open GitHub site">
          <StackPanel Orientation="Horizontal">
             <iconPacks:PackIconModern Kind="SocialGithubOctocat"/>
          </StackPanel>
        </Button>
        <Button Name="Twitter" ToolTip="Almens Twitter - @almenscorner">
          <StackPanel Orientation="Horizontal">
             <iconPacks:PackIconModern Kind="SocialTwitter"/>
          </StackPanel>
        </Button>
        </mah:WindowCommands>
    </mah:MetroWindow.LeftWindowCommands>
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="49*"/>
            <ColumnDefinition Width="437*"/>
            <ColumnDefinition Width="314*"/>
        </Grid.ColumnDefinitions>
        <Button x:Name="button" Content="Select package folder" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top" Grid.ColumnSpan="2"/>
        <Button x:Name="addpackage" Content="Upload packages" Grid.Column="2" HorizontalAlignment="Left" Margin="3,204,0,0" VerticalAlignment="Top"/>
        <Button x:Name="removepackage" Content="Remove Package" Grid.Column="1" HorizontalAlignment="Left" Margin="100,10,0,0" VerticalAlignment="Top"/>
        <DataGrid x:Name="grid" Grid.ColumnSpan="2" Margin="10,48,39,32" AutoGenerateColumns="False">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Assign to" Binding="{Binding AssignTo}" Width="100" Visibility="Hidden"/>
                <DataGridTextColumn Header="Package Name" Binding="{Binding PackageName}"/>
                <DataGridTextColumn Header="CFBundleShortVersion" Binding="{Binding CFBundleShortVersion}" IsReadOnly="False"/>
                <DataGridTextColumn Header="Install Path" Binding="{Binding InstallPath}" Width="180" IsReadOnly="False"/>
                <DataGridTextColumn Header="FullName" Binding="{Binding FullName}" Width="180" Visibility="Hidden"/>
                <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="180" Visibility="Hidden"/>
            </DataGrid.Columns>      
        </DataGrid>
        <TextBlock Grid.Column="2" HorizontalAlignment="Left" Margin="424,45,0,0" Text="Storage Account name" TextWrapping="Wrap" VerticalAlignment="Top"/>
        <TextBlock Grid.Column="2" HorizontalAlignment="Left" Margin="157,45,0,0" Text="Resource Group name" TextWrapping="Wrap" VerticalAlignment="Top"/>
        <TextBlock x:Name="comboboxNull" Grid.Column="2" HorizontalAlignment="Left" Margin="0,277,0,0" Text="All text fields are requierd" TextWrapping="Wrap" VerticalAlignment="Top" Foreground="Red" Visibility="Hidden"/>  
        <ComboBox x:Name="rsgroupbox" Grid.Column="2" HorizontalAlignment="Left" Margin="157,66,0,0" VerticalAlignment="Top" Width="120"/>
        <TextBlock x:Name="uploading" Grid.Column="2" HorizontalAlignment="Left" Margin="5,233,0,0" Text="Uploading packages..." FontWeight="Bold" TextWrapping="Wrap" VerticalAlignment="Top" Visibility="Hidden"/>
        <TextBlock Grid.Column="2" HorizontalAlignment="Left" Margin="3,45,0,0" Text="Storage Account name" TextWrapping="Wrap" VerticalAlignment="Top" Height="16" Width="120"/>
        <ComboBox x:Name="staccbox" Grid.Column="2" HorizontalAlignment="Left" Margin="3,66,0,0" VerticalAlignment="Top" Width="120" RenderTransformOrigin="0.417,-11" Height="22"/>
        <TextBlock Grid.Column="2" HorizontalAlignment="Left" Margin="3,98,0,0" Text="Container name" TextWrapping="Wrap" VerticalAlignment="Top" Height="16" Width="84"/>
        <ComboBox x:Name="containerbox" Grid.Column="2" HorizontalAlignment="Left" Margin="3,119,0,0" VerticalAlignment="Top" Width="120" Height="22"/>
        <TextBlock HorizontalAlignment="Left" Margin="6,396,0,0" Text="Provided by almenscorner.io" TextWrapping="Wrap" VerticalAlignment="Top" Grid.ColumnSpan="2" Opacity="0.5"/>
        <TextBlock Grid.Column="2" HorizontalAlignment="Left" Margin="157,98,0,0" Text="Assign to" TextWrapping="Wrap" VerticalAlignment="Top"/>
        <TextBox x:Name="groupname" Grid.Column="2" HorizontalAlignment="Left" Margin="157,119,0,0" Text="" TextWrapping="Wrap" VerticalAlignment="Top" Width="81" Height="22"/>
        <Button x:Name="searchgroup" Content="Search" Grid.Column="2" HorizontalAlignment="Left" Margin="238,119,0,0" VerticalAlignment="Top" Height="26"/>
        <TextBlock x:Name="grouperror" Grid.Column="2" HorizontalAlignment="Left" Margin="157,147,0,0" Text="Could not find group" TextWrapping="Wrap" VerticalAlignment="Top" Foreground="#FFFB0000" Visibility="Hidden"/>
    </Grid>
</mah:MetroWindow>
"@ 
 
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
#Read XAML
 
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
try{
    $Form=[Windows.Markup.XamlReader]::Load( $reader )
}
catch{
    Write-Warning "Unable to parse XML, with error: $($Error[0])`n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"
    throw
}
 
#===========================================================================
# Load XAML Objects In PowerShell
#===========================================================================
$xaml.SelectNodes("//*[@Name]") | %{"trying item $($_.Name)";
    try {Set-Variable –Name "WPF$($_.Name)" –Value $Form.FindName($_.Name) –ErrorAction Stop}
    catch{throw}
    } | out-null
 
Function Get-FormVariables{
get-variable WPF*
}
 
Get-FormVariables | out-null
 
#===========================================================================
# Add timer for upload jobs
#===========================================================================
$JobTrackerList = New-Object System.Collections.ArrayList
$timerJobTracker = New-Object System.Windows.Forms.Timer 
$timerJobTracker.add_Tick({ Update-JobTracker }) 
$timerJobTracker.Enabled = $true 
$timerJobTracker.Start() 

#===========================================================================
# Functions
#===========================================================================
function Get-CFBundleShortVersion {
    param (
        $packagePath
    )

    #Check if 7-zip is installed
    $checkInstall = (gp HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*).DisplayName -Match "7-zip"

    if (!$checkInstall){
        Write-Host -ForegroundColor Yellow "Warning: 7-zip is not installed, provide CFBundleShortVersion manually"
    }

    #If installed, get CFBundleShortVersion from package
    else {
        #Get 7-zip install location
        $7zipLocation = (gp HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*).InstallLocation -Match "7-zip"

        #Check if package is a DMG
        if($packagePath -like "*.dmg") {
            #Set parameters and extract Info.plist
            $cmd = "$7zipLocation\7z.exe"
            $params = "e $packagePath -o.\ *\*\Contents\Info.plist -y"
            $params = $params.Split(" ")
            & $cmd $params > $null 2>&1
            #Get version as string and delete Info.plist
            if (test-path .\Info.plist -PathType Leaf){
                $plistContent =  ($(Get-Content .\Info.plist -Raw) -split "<key>" | Where-Object {$_ -match 'CFBundleShortVersion'}).ToString()
                $trimContent = $plistContent.Trim()
                $vString = $trimContent.Split()
                $version = $vString[2].Trim("<string>,</")
                $Script:CFBundleVers = $version.ToString()
                Remove-Item .\Info.plist -Force
            }
        }

        if ($packagePath -like "*.pkg") {
            $cmd = "$7zipLocation\7z.exe"
            #Set parameters and extract Payload~
            $params = "e $packagePath -o.\ -y"
            $params = $params.Split(" ")
            & $cmd $params > $null 2>&1
            #Set parameters and extract Info.plist
            $params = "e .\Payload~ -o.\ *\*\*\Contents\Info.plist -y"
            $params = $params.Split(" ")
            & $cmd $params > $null 2>&1
            #Get version as string and delete Info.plist and Payload~
            if (test-path .\Info.plist -PathType Leaf){
                $plistContent =  ($(Get-Content .\Info.plist -Raw) -split "<key>" | Where-Object {$_ -match 'CFBundleShortVersion'}).ToString()
                $trimContent = $plistContent.Trim()
                $vString = $trimContent.Split()
                $version = $vString[2].Trim("<string>,</")
                $Script:CFBundleVers = $version.ToString()
                Remove-Item .\Info.plist -Force
                Remove-Item .\Payload~ -Force
            }
        }
    }

    if (!$CFBundleVers){
        Write-Host -ForegroundColor Yello "Warning: Unable to extract CFBundleShortVersion for $packagePath"
    }

}

function Add-JobTracker
{
    <#
        .SYNOPSIS
            Add a new job to the JobTracker and starts the timer.
    
        .DESCRIPTION
            Add a new job to the JobTracker and starts the timer.
    
        .PARAMETER  Name
            The name to assign to the Job
    
        .PARAMETER  JobScript
            The script block that the Job will be performing. 
            Important: Do not access form controls from this script block.
    
        .PARAMETER ArgumentList
            The arguments to pass to the job
    
        .PARAMETER  CompleteScript
            The script block that will be called when the job is complete.
            The job is passed as an argument. The Job argument is null when the job fails.
    
        .PARAMETER  UpdateScript
            The script block that will be called each time the timer ticks. 
            The job is passed as an argument. Use this to get the Job's progress.
    
        .EXAMPLE
            Job-Begin -Name "JobName" `
            -JobScript {    
                Param($Argument1)#Pass any arguments using the ArgumentList parameter
                #Important: Do not access form controls from this script block.
                Get-WmiObject Win32_Process -Namespace "root\CIMV2"
            }`
            -CompletedScript {
                Param($Job)        
                $results = Receive-Job -Job $Job        
            }`
            -UpdateScript {
                Param($Job)
                #$results = Receive-Job -Job $Job -Keep
            }
    
        .LINK
            
    #>
    
    Param(
    [ValidateNotNull()]
    [Parameter(Mandatory=$true)]
    [string]$Name, 
    [ValidateNotNull()]
    [Parameter(Mandatory=$true)]
    [ScriptBlock]$JobScript,
    $ArgumentList = $null,
    [ScriptBlock]$CompletedScript,
    [ScriptBlock]$UpdateScript)
    
    #Start the Job
    $job = Start-Job -Name $Name -ScriptBlock $JobScript -ArgumentList $ArgumentList
    
    if($job -ne $null)
    {
        #Create a Custom Object to keep track of the Job & Script Blocks
        $psObject = New-Object System.Management.Automation.PSObject
        
        Add-Member -InputObject $psObject -MemberType 'NoteProperty' -Name Job  -Value $job
        Add-Member -InputObject $psObject -MemberType 'NoteProperty' -Name CompleteScript  -Value $CompletedScript
        Add-Member -InputObject $psObject -MemberType 'NoteProperty' -Name UpdateScript  -Value $UpdateScript
        
        [void]$JobTrackerList.Add($psObject)
        
        #Start the Timer
        if(-not $timerJobTracker.Enabled)
        {
            $timerJobTracker.Start()
        }
    }
    elseif($CompletedScript -ne $null)
    {
        #Failed
        Invoke-Command -ScriptBlock $CompletedScript -ArgumentList $null
    }

}

function Update-JobTracker
{
    <#
        .SYNOPSIS
            Checks the status of each job on the list.
    #>
    
    #Poll the jobs for status updates
    $timerJobTracker.Stop() #Freeze the Timer
    
    for($index =0; $index -lt $JobTrackerList.Count; $index++)
    {
        $psObject = $JobTrackerList[$index]
        
        if($psObject -ne $null) 
        {
            if($psObject.Job -ne $null)
            {
                if($psObject.Job.State -ne "Running")
                {                
                    #Call the Complete Script Block
                    if($psObject.CompleteScript -ne $null)
                    {
                        #$results = Receive-Job -Job $psObject.Job
                        Invoke-Command -ScriptBlock $psObject.CompleteScript -ArgumentList $psObject.Job
                    }
                    
                    $JobTrackerList.RemoveAt($index)
                    Remove-Job -Job $psObject.Job
                    $index-- #Step back so we don't skip a job
                }
                elseif($psObject.UpdateScript -ne $null)
                {
                    #Call the Update Script Block
                    Invoke-Command -ScriptBlock $psObject.UpdateScript -ArgumentList $psObject.Job
                }
            }
        }
        else
        {
            $JobTrackerList.RemoveAt($index)
            $index-- #Step back so we don't skip a job
        }
    }
    
    if($JobTrackerList.Count -gt 0)
    {
        $timerJobTracker.Start()#Resume the timer    
    }    
}

function Stop-JobTracker
{
   <#
        .SYNOPSIS
            Stops and removes all Jobs from the list.
    #>
   #Stop the timer
   $timerJobTracker.Stop()
    
   #Remove all the jobs
   while($JobTrackerList.Count-gt 0)
    {
       $job = $JobTrackerList[0].Job
       $JobTrackerList.RemoveAt(0)
       Stop-Job $job
       Remove-Job $job
    }
}

#===========================================================================
# Import modules and connect to Azure and Graph
#===========================================================================
Import-Module Az.Storage | out-null
Import-Module Microsoft.Graph.Authentication | out-null

Connect-AzAccount | out-null
Connect-MGGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"
Select-MgProfile -Name beta

$staccount = Get-AzStorageAccount
$key = Get-AzStorageAccountKey -Name $staccount.StorageAccountName -ResourceGroupName $staccount.ResourceGroupName | select-object -First 1 -ExpandProperty Value
$ctx = New-AzStorageContext -StorageAccountName $staccount.StorageAccountName -StorageAccountKey $key
$containers = Get-AzStorageContainer -Context $ctx

#===========================================================================
# Disable buttons until folder is selected
#===========================================================================
$WPFaddpackage.IsEnabled = $false
$WPFremovepackage.IsEnabled = $false
$WPFsearchgroup.IsEnabled = $false

#===========================================================================
# Populate ComboBox with Storage Account, Resource Groups and Container
#===========================================================================
foreach ($account in $staccount.StorageAccountName){
    $WPFstaccbox.Items.Add($account) | out-null
}

foreach ($rsgroup in $staccount.ResourceGroupName){
    $WPFrsgroupbox.Items.Add($rsgroup) | out-null
}

foreach ($container in $containers.Name){
    $WPFcontainerbox.Items.Add($container) | out-null
}

#===========================================================================
# Select folder button action
#===========================================================================                                             
$WPFbutton.Add_Click({

    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $null = $browser.ShowDialog()

    $itemsArray = @()  
    $packages = Get-ChildItem $browser.SelectedPath | where {$_.Name -like "*.pkg" -or $_.Name -like "*.dmg"}

    foreach ($package in $packages){
        
        Get-CFBundleShortVersion -packagePath $package.FullName

        if ($CFBundleVers){
            $array = @([pscustomobject]@{PackageName=$package.Name;CFBundleShortVersion=$CFBundleVers;InstallPath="/Applications";FullName=$package.FullName})
            $itemsArray += $array
        }
        else{
            $array = @([pscustomobject]@{PackageName=$package.Name;CFBundleShortVersion="";InstallPath="/Applications";FullName=$package.FullName})
            $itemsArray += $array
        }
    }
    
    $WPFgrid.ItemsSource = $itemsArray

    $WPFaddpackage.IsEnabled = $true
    $WPFremovepackage.IsEnabled = $true
    $WPFsearchgroup.IsEnabled = $true

})

#===========================================================================
# Remove package from datagrid
#===========================================================================
$WPFremovepackage.Add_Click({

    $removeItem = $WPFgrid.SelectedItem
    [System.Collections.ArrayList]$itemsArray = @()
    $itemsArray += $WPFgrid.ItemsSource

    $itemsArray.Remove($removeItem)

    $WPFgrid.ItemsSource = $itemsArray

})

#===========================================================================
# Assign packages to group
#===========================================================================
$WPFsearchgroup.Add_Click({
    $Script:group = Get-MgGroup -Filter "displayName eq '$($WPFgroupname.Text)'"
    if ($group){
        $WPFgrouperror.Visibility = "Hidden"
        $WPFgrid.Columns[0].Visibility = "Visible"
        $items = $WPFgrid.Items
        [System.Collections.ArrayList]$itemsArray = @()
        $itemsArray += $WPFgrid.ItemsSource
        $itemsArray | Add-Member -MemberType NoteProperty -Name AssignTo -Value $group.DisplayName -force
        $WPFgrid.ItemsSource = $itemsArray
    }
    else{
        $WPFgrouperror.Visibility = "Visible"
    }

})

#===========================================================================
# Upload package button actions
#===========================================================================
$WPFaddpackage.Add_Click({

    if ((!$WPFstaccbox.SelectedValue) -or (!$WPFrsgroupbox.SelectedValue) -or (!$WPFcontainerbox.SelectedValue)){
        
        $WPFtextNull.Visibility = "Visible" 

    }

    else {

        Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
        Write-Host -ForegroundColor DarkGray "Uploading packages"
        Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
        
        foreach ($item in $WPFgrid.Items | where {$_.CFBundleShortVersion -and $_.InstallPath}){

            $blob = Get-AzStorageBlob -Context $ctx -Blob $item.PackageName -Container $WPFcontainerbox.SelectedValue -ErrorAction SilentlyContinue
            $blobVersion = $blob.ICloudBlob.Metadata.Version
        
            if (($blobVersion) -and ($item.CFBundleShortVersion -ge $blobVersion)){
                Write-Host -ForegroundColor Yellow "Warning: Latest version already exists for $($item.PackageName)"
            }

            else {

                try {
                    Add-JobTracker -Name "uploadLOB" `
                        -JobScript {
                            $key = Get-AzStorageAccountKey `
                            -Name $using:staccount.StorageAccountName `
                            -ResourceGroupName $using:staccount.ResourceGroupName `
                            | select-object -First 1 -ExpandProperty Value
                            $ctx = New-AzStorageContext `
                            -StorageAccountName $using:staccount.StorageAccountName `
                            -StorageAccountKey $key

                            $ProgressPreference = "SilentlyContinue"

                            $Metadata = @{"Version" = "$($using:item.CFBundleShortVersion)"}

                            $upload = Set-AzStorageBlobContent `
                            -Container $using:WPFcontainerbox.SelectedValue `
                            -File $using:item.FullName `
                            -Blob $using:item.PackageName `
                            -Context $ctx `
                            -Metadata $Metadata
                            
                        }`
                        -UpdateScript {
                            Param($Job)
                            $results = Receive-Job -Job $Job -Keep
                            $WPFuploading.Visibility = "Visible"
                                
                        }`
                        -CompletedScript {
                            Param($Job)
                            $results = Receive-Job -Job $Job
                            $WPFuploading.Visibility = "Hidden"
                            Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                            Write-Host -ForegroundColor DarkGray "Upload finished"
                            Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                                
                        }
                    }

                    catch{
                        Write-Host -ForegroundColor Yellow "Warning: Failed to create upload job"
                        break
                    }

                try {
                    Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                    Write-Host -ForegroundColor DarkGray "Adding install script parameters for $($item.PackageName)"
                    Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                    $scriptName = "$($item.PackageName)-$($item.CFBundleShortVersion).sh"
                    Copy-Item ".\Scripts\installapp.sh" ".\Scripts\$scriptName" | out-null
                    $scriptContent = Get-Content ".\Scripts\$scriptName" -raw
                            
                    (($scriptContent) -replace 'baseURL=""', "baseURL=""https://$($WPFstaccbox.SelectedValue).blob.core.windows.net"" " `
                                    -replace 'packageName=""', "packageName=""$($item.PackageName)"" " `
                                    -replace 'CFBundleShortVersion=""', "CFBundleShortVersion=""$($item.CFBundleShortVersion)"" " `
                                    -replace 'installLocation=""', "installLocation=""$($item.InstallPath)"" " `
                                    -replace 'container=""', "container=""$($WPFcontainerbox.SelectedValue)"" ") `
                                    | Set-Content -Path ".\Scripts\$scriptName"

                    }
                    catch {
                        Write-Host -ForegroundColor Yellow "Warning: Failed to set script parameters"
                        break
                    }

                try {
                    $script = (Get-Content ".\Scripts\$scriptName" -raw) -replace "`r`n","`n"
                    $scriptContent = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
                }

                catch{
                    Write-Host -ForegroundColor Yellow "Warning: Failed to get script content"
                    break
                }

                try {
                    Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                    Write-Host -ForegroundColor DarkGray "Adding $($item.PackageName) install script to MEM"
                    Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                    $RequestBodyObject = @{
                        "@odata.type" = "#microsoft.graph.deviceShellScript"
                        retryCount = 3
                        blockExecutionNotifications = $false
                        displayName = $scriptName
                        scriptContent = $scriptContent
                        fileName = $scriptName
                    }

                    $body = $RequestBodyObject | ConvertTo-Json
 
                    $newScriptRequest = Invoke-MGGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts" -Body $body -ContentType 'application/json'
                    Remove-Item ".\Scripts\$scriptName" -Force
                }

                catch{
                    Write-Host -ForegroundColor Yellow "Warning: Failed to add scripts to MEM"
                    break
                }

                try {
                    if ($group){
                        Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                        Write-Host -ForegroundColor DarkGray "Assigning $($item.PackageName) to group $($group.DisplayName)"
                        Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                        
                        $RequestBodyObject = @( 
                            @{deviceManagementScriptAssignments =
                                @( 
                                    @{target = 
                                        @{
                                            '@odata.type' = "#microsoft.graph.groupAssignmentTarget";
                                            groupId = $group.Id
                                        }
                                    }
                                )
                            }
                        )

                        $body = $RequestBodyObject | ConvertTo-Json -Depth 10
                        Invoke-MGGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts/$($newScriptRequest.id)/assign" -Body $body -ContentType 'application/json'
                    }
                }

                catch{
                    Write-Host -ForegroundColor Yellow "Warning: Failed to assign script"
                }


            }            

        }
            $WPFuploading.Visibility = "Hidden"
    }

})

#===========================================================================
# Show form
#===========================================================================
$Form.ShowDialog() | out-null
