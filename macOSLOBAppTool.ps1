<#
    .SYNOPSIS
        WPF GUI tool to manage macOS LOB apps in MEM.
        Created by: Tobias Almen
    
    .DESCRIPTION
        This tool is designed to manage macOS apps that cannot be distributed via MEM as a .intunemac file.
        Instead of wrapping the application, the .pkg or .dmg is uploaded to an Azure storage blob and a shell script
        is created in MEM. When the script runs on a mac, it curls the package from the blob and if it's a DMG, mounts
        and installs or if it's a PKG, installs directly.
        7-zip must be installed since it's used to extarct the CFBundleName for the app
        from the Info.plist file.
        Per default, the processpath is set to /Applications. If needed this can be changed. This path is needed to detect if
        the app is running if you set "terminateprocess" to true when updating an app.
        It's assumed that the container on the storage account is publicly available.
    .LINK
        https://github.com/almenscorner/macOSLOBAppTool
#>  

#--------------------------------------------------------------------------#
# Add assemblies
#--------------------------------------------------------------------------#
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$AssemblyLocation = Join-Path -Path $ScriptPath -ChildPath .\Assembly
foreach ($Assembly in (Dir $AssemblyLocation -Filter *.dll)) {
     [System.Reflection.Assembly]::LoadFrom($Assembly.fullName) | out-null
}

#--------------------------------------------------------------------------#
# XAML
#--------------------------------------------------------------------------#
$inputXML = @"
<mah:MetroWindow
        
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    xmlns:mah="http://metro.mahapps.com/winfx/xaml/controls"
    xmlns:iconPacks="http://metro.mahapps.com/winfx/xaml/iconpacks"
    xmlns:local="clr-namespace:macOSLOBapp"
    WindowStartupLocation="CenterScreen"
    mc:Ignorable="d"
    Title="macOS LOB App Tool" Height="490" Width="820">

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
                    <iconPacks:PackIconMaterial Kind="GitHub"/>
                </StackPanel>
            </Button>
            <Button Name="Twitter" ToolTip="Almens Twitter - @almenscorner">
                <StackPanel Orientation="Horizontal">
                    <iconPacks:PackIconMaterial Kind="Twitter"/>
                </StackPanel>
            </Button>
        </mah:WindowCommands>
    </mah:MetroWindow.LeftWindowCommands>
    <mah:MetroWindow.RightWindowCommands>
        <mah:WindowCommands>
            <Button Name="ThemeSwitcher">
                <StackPanel Orientation="Horizontal">
                    <iconPacks:PackIconMaterial Kind="Brightness6"/>
                </StackPanel>
            </Button>
        </mah:WindowCommands>
    </mah:MetroWindow.RightWindowCommands>
    <Grid ForceCursor="True">
    <TextBlock HorizontalAlignment="Left" Margin="657,95,0,0" Text="Resource Group name" TextWrapping="Wrap" VerticalAlignment="Top"/>
    <ComboBox x:Name="rsgroupbox" HorizontalAlignment="Left" Margin="657,116,0,0" VerticalAlignment="Top" Width="120"/>
    <TextBlock HorizontalAlignment="Left" Margin="503,95,0,0" Text="Storage Account name" TextWrapping="Wrap" VerticalAlignment="Top" Height="16" Width="120"/>
    <ComboBox x:Name="staccbox" HorizontalAlignment="Left" Margin="503,116,0,0" VerticalAlignment="Top" Width="120" RenderTransformOrigin="0.417,-11" Height="22"/>
    <TextBlock HorizontalAlignment="Left" Margin="503,148,0,0" Text="Container name" TextWrapping="Wrap" VerticalAlignment="Top" Height="16" Width="84"/>
    <ComboBox x:Name="containerbox" HorizontalAlignment="Left" Margin="503,169,0,0" VerticalAlignment="Top" Width="120" Height="22"/>
    <TextBlock HorizontalAlignment="Left" Margin="657,148,0,0" Text="Assign to" TextWrapping="Wrap" VerticalAlignment="Top"/>
    <TextBox x:Name="groupname" HorizontalAlignment="Left" Margin="657,169,0,0" Text="" TextWrapping="Wrap" VerticalAlignment="Top" Width="81" Height="22"/>
    <Button x:Name="searchgroup" Content="Search" HorizontalAlignment="Left" Margin="738,169,0,0" VerticalAlignment="Top" Height="26"/>
    <TextBlock x:Name="comboboxNull" Grid.Column="2" HorizontalAlignment="Left" Margin="0,277,0,0" Text="All text fields are requierd" TextWrapping="Wrap" VerticalAlignment="Top" Foreground="Red" Visibility="Hidden"/>
    <TextBlock x:Name="grouperror" Grid.Column="2" HorizontalAlignment="Left" Margin="157,147,0,0" Text="Could not find group" TextWrapping="Wrap" VerticalAlignment="Top" Foreground="#FFFB0000" Visibility="Hidden"/>
        <mah:MetroAnimatedTabControl x:Name="tabcontrol" Margin="0,0,400,0">
            <TabItem x:Name="tabnew" Header="New" Margin="0,4,0,0">
                <TabItem.HeaderTemplate>
                    <ItemContainerTemplate>
                        <StackPanel Orientation="Vertical">
                            <iconPacks:PackIconMaterial Width="25" Height="25" Kind="PlusCircleOutline" HorizontalAlignment="Center"/>
                            <TextBlock FontSize="16">New</TextBlock>
                        </StackPanel>
                    </ItemContainerTemplate>
                </TabItem.HeaderTemplate>
                <Grid Margin="0,0,-45,0">
                    <Button x:Name="button" Content="Select package folder" HorizontalAlignment="Left" Margin="10,6,0,0" VerticalAlignment="Top"/>
                    <Button x:Name="addpackage" HorizontalAlignment="Left" Margin="359,6,0,0" VerticalAlignment="Top">
                        <mah:Badged x:Name="Badge1" Content="UPLOAD PACKAGES" Badge="{Binding Path=BadgeValue}" BadgePlacementMode="TopRight" BadgeBackground="Green"/>
                    </Button>
                    <Button x:Name="removepackage" Content="Remove Package" HorizontalAlignment="Left" Margin="147,6,0,0" VerticalAlignment="Top"/>
                    <DataGrid x:Name="grid" Margin="7,41,0,27" AutoGenerateColumns="False" AlternationCount="2" AlternatingRowBackground="LightBlue" CanUserAddRows="false">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Assign to" Binding="{Binding AssignTo}" Width="100" Visibility="Hidden"/>
                            <DataGridTextColumn Header="App Name" Binding="{Binding AppName}" IsReadOnly="False"/>
                            <DataGridTextColumn Header="App" Binding="{Binding App}" IsReadOnly="False"/>
                            <DataGridTextColumn Header="Process Path" Binding="{Binding ProcessPath}" Width="180" IsReadOnly="False"/>
                            <DataGridTextColumn Header="Terminate Process" Binding="{Binding TerminateProcess}" IsReadOnly="False"/>
                            <DataGridTextColumn Header="Autoupdate" Binding="{Binding Autoupdate}" IsReadOnly="False"/>
                            <DataGridTextColumn Header="FullName" Binding="{Binding FullName}" Visibility="Hidden"/>
                            <DataGridTextColumn Header="FileName" Binding="{Binding FileName}" Visibility="Hidden"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </Grid>
            </TabItem>
            <TabItem x:Name="tabupdate" Header="Update" Margin="0,4,0,0">
                <TabItem.HeaderTemplate>
                    <ItemContainerTemplate>
                        <StackPanel Orientation="Vertical">
                            <iconPacks:PackIconMaterial Width="25" Height="25" Kind="Update" HorizontalAlignment="Center"/>
                            <TextBlock FontSize="16">Update</TextBlock>
                        </StackPanel>
                    </ItemContainerTemplate>
                </TabItem.HeaderTemplate>
                <Grid Margin="0,0,-45,0">
                    <Button x:Name="updatepackagebutton" Content="Select new package" HorizontalAlignment="Left" Margin="10,6,0,0" VerticalAlignment="Top"/>
                    <DataGrid x:Name="updatepackagegrid" Margin="7,41,0,27" AutoGenerateColumns="False" CanUserAddRows="false">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Assign to" Binding="{Binding AssignTo}" Width="100" Visibility="Hidden"/>
                            <DataGridTextColumn Header="App Name" Binding="{Binding AppName}" IsReadOnly="False"/>
                            <DataGridTextColumn Header="App" Binding="{Binding App}" IsReadOnly="False"/>
                            <DataGridTextColumn Header="Process Path" Binding="{Binding ProcessPath}" Width="180" IsReadOnly="False"/>
                            <DataGridTextColumn Header="Terminate Process" Binding="{Binding TerminateProcess}" IsReadOnly="False"/>
                            <DataGridTextColumn Header="Autoupdate" Binding="{Binding Autoupdate}" IsReadOnly="False"/>
                            <DataGridTextColumn Header="FullName" Binding="{Binding FullName}" Visibility="Hidden"/>
                            <DataGridTextColumn Header="FileName" Binding="{Binding FileName}" Visibility="Hidden"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    <Button x:Name="getpackagesbutton" Content="Get packages" HorizontalAlignment="Left" Margin="7,134,0,0" VerticalAlignment="Top"/>
                    <ComboBox x:Name="packagesbox" HorizontalAlignment="Left" Margin="7,160,0,0" VerticalAlignment="Top" Width="134" Grid.ColumnSpan="2"/>
                    <TextBlock HorizontalAlignment="Left" Margin="7,114,0,0" Text="Select package to update" TextWrapping="Wrap" VerticalAlignment="Top" Grid.ColumnSpan="2"/>
                    <CheckBox x:Name="removecheck" Content="Remove" HorizontalAlignment="Left" Margin="7,194,0,0" VerticalAlignment="Top" Grid.ColumnSpan="2"/>
                    <Button x:Name="updatebutton" HorizontalAlignment="Left" Margin="134,6,0,0" VerticalAlignment="Top">
                        <mah:Badged x:Name="Badge2" Content="UPDATE" Badge="{Binding Path=BadgeValue}" BadgePlacementMode="TopRight" BadgeBackground="Green"/>
                    </Button>
                </Grid>
            </TabItem>
        </mah:MetroAnimatedTabControl>
        <TextBlock HorizontalAlignment="Left" Margin="10,435,0,0" Text="Provided by almenscorner.io" TextWrapping="Wrap" VerticalAlignment="Top" Opacity="0.5"/>
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
 
#--------------------------------------------------------------------------#
# Load XAML Objects In PowerShell
#--------------------------------------------------------------------------#
$xaml.SelectNodes("//*[@Name]") | %{"trying item $($_.Name)";
    try {Set-Variable –Name "WPF$($_.Name)" –Value $Form.FindName($_.Name) –ErrorAction Stop}
    catch{throw}
    } | out-null
 
Function Get-FormVariables{
get-variable WPF*
}
 
Get-FormVariables | out-null

#--------------------------------------------------------------------------#
# Functions
#--------------------------------------------------------------------------#

function New-WPFMessageBox {

    # For examples for use, see my blog:
    # https://smsagent.wordpress.com/2017/08/24/a-customisable-wpf-messagebox-for-powershell/
    
    # CHANGES
    # 2017-09-11 - Added some required assemblies in the dynamic parameters to avoid errors when run from the PS console host.
    
    # Define Parameters
    [CmdletBinding()]
    Param
    (
        # The popup Content
        [Parameter(Mandatory=$True,Position=0)]
        [Object]$Content,

        # The window title
        [Parameter(Mandatory=$false,Position=1)]
        [string]$Title,

        # The buttons to add
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateSet('OK','OK-Cancel','Abort-Retry-Ignore','Yes-No-Cancel','Yes-No','Retry-Cancel','Cancel-TryAgain-Continue','None')]
        [array]$ButtonType = 'OK',

        # The buttons to add
        [Parameter(Mandatory=$false,Position=3)]
        [array]$CustomButtons,

        # Content font size
        [Parameter(Mandatory=$false,Position=4)]
        [int]$ContentFontSize = 14,

        # Title font size
        [Parameter(Mandatory=$false,Position=5)]
        [int]$TitleFontSize = 14,

        # BorderThickness
        [Parameter(Mandatory=$false,Position=6)]
        [int]$BorderThickness = 0,

        # CornerRadius
        [Parameter(Mandatory=$false,Position=7)]
        [int]$CornerRadius = 8,

        # ShadowDepth
        [Parameter(Mandatory=$false,Position=8)]
        [int]$ShadowDepth = 3,

        # BlurRadius
        [Parameter(Mandatory=$false,Position=9)]
        [int]$BlurRadius = 20,

        # WindowHost
        [Parameter(Mandatory=$false,Position=10)]
        [object]$WindowHost,

        # Timeout in seconds,
        [Parameter(Mandatory=$false,Position=11)]
        [int]$Timeout,

        # Code for Window Loaded event,
        [Parameter(Mandatory=$false,Position=12)]
        [scriptblock]$OnLoaded,

        # Code for Window Closed event,
        [Parameter(Mandatory=$false,Position=13)]
        [scriptblock]$OnClosed

    )

    # Dynamically Populated parameters
    DynamicParam {
        
        # Add assemblies for use in PS Console 
        Add-Type -AssemblyName System.Drawing, PresentationCore
        
        # ContentBackground
        $ContentBackground = 'ContentBackground'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.ContentBackground = "White"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ContentBackground, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ContentBackground, $RuntimeParameter)
        

        # FontFamily
        $FontFamily = 'FontFamily'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute)  
        $arrSet = [System.Drawing.FontFamily]::Families.Name | Select -Skip 1 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($FontFamily, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($FontFamily, $RuntimeParameter)
        $PSBoundParameters.FontFamily = "Segoe UI"

        # TitleFontWeight
        $TitleFontWeight = 'TitleFontWeight'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Windows.FontWeights] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.TitleFontWeight = "Normal"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($TitleFontWeight, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($TitleFontWeight, $RuntimeParameter)

        # ContentFontWeight
        $ContentFontWeight = 'ContentFontWeight'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Windows.FontWeights] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.ContentFontWeight = "Normal"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ContentFontWeight, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ContentFontWeight, $RuntimeParameter)
        

        # ContentTextForeground
        $ContentTextForeground = 'ContentTextForeground'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.ContentTextForeground = "Black"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ContentTextForeground, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ContentTextForeground, $RuntimeParameter)

        # TitleTextForeground
        $TitleTextForeground = 'TitleTextForeground'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.TitleTextForeground = "Black"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($TitleTextForeground, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($TitleTextForeground, $RuntimeParameter)

        # BorderBrush
        $BorderBrush = 'BorderBrush'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.BorderBrush = "Black"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($BorderBrush, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($BorderBrush, $RuntimeParameter)


        # TitleBackground
        $TitleBackground = 'TitleBackground'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.TitleBackground = "White"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($TitleBackground, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($TitleBackground, $RuntimeParameter)

        # ButtonTextForeground
        $ButtonTextForeground = 'ButtonTextForeground'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.ButtonTextForeground = "Black"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ButtonTextForeground, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ButtonTextForeground, $RuntimeParameter)

        # Sound
        $Sound = 'Sound'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        #$ParameterAttribute.Position = 14
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = (Get-ChildItem "$env:SystemDrive\Windows\Media" -Filter Windows* | Select -ExpandProperty Name).Replace('.wav','')
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($Sound, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($Sound, $RuntimeParameter)

        return $RuntimeParameterDictionary
    }

    Begin {
        Add-Type -AssemblyName PresentationFramework
    }
    
    Process {

# Define the XAML markup
[XML]$Xaml = @"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="Window" Title="" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" Opacity="1">
    <Window.Resources>
        <Style TargetType="{x:Type Button}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border>
                            <Grid Background="{TemplateBinding Background}">
                                <ContentPresenter />
                            </Grid>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Border x:Name="MainBorder" Margin="10" CornerRadius="$CornerRadius" BorderThickness="$BorderThickness" BorderBrush="$($PSBoundParameters.BorderBrush)" Padding="0" >
        <Border.Effect>
            <DropShadowEffect x:Name="DSE" Color="Black" Direction="270" BlurRadius="$BlurRadius" ShadowDepth="$ShadowDepth" Opacity="0.6" />
        </Border.Effect>
        <Border.Triggers>
            <EventTrigger RoutedEvent="Window.Loaded">
                <BeginStoryboard>
                    <Storyboard>
                        <DoubleAnimation Storyboard.TargetName="DSE" Storyboard.TargetProperty="ShadowDepth" From="0" To="$ShadowDepth" Duration="0:0:1" AutoReverse="False" />
                        <DoubleAnimation Storyboard.TargetName="DSE" Storyboard.TargetProperty="BlurRadius" From="0" To="$BlurRadius" Duration="0:0:1" AutoReverse="False" />
                    </Storyboard>
                </BeginStoryboard>
            </EventTrigger>
        </Border.Triggers>
        <Grid >
            <Border Name="Mask" CornerRadius="$CornerRadius" Background="$($PSBoundParameters.ContentBackground)" />
            <Grid x:Name="Grid" Background="$($PSBoundParameters.ContentBackground)">
                <Grid.OpacityMask>
                    <VisualBrush Visual="{Binding ElementName=Mask}"/>
                </Grid.OpacityMask>
                <StackPanel Name="StackPanel" >                   
                    <TextBox Name="TitleBar" IsReadOnly="True" IsHitTestVisible="False" Text="$Title" Padding="10" FontFamily="$($PSBoundParameters.FontFamily)" FontSize="$TitleFontSize" Foreground="$($PSBoundParameters.TitleTextForeground)" FontWeight="$($PSBoundParameters.TitleFontWeight)" Background="$($PSBoundParameters.TitleBackground)" HorizontalAlignment="Stretch" VerticalAlignment="Center" Width="Auto" HorizontalContentAlignment="Center" BorderThickness="0"/>
                    <DockPanel Name="ContentHost" Margin="0,10,0,10"  >
                    </DockPanel>
                    <DockPanel Name="ButtonHost" LastChildFill="False" HorizontalAlignment="Center" >
                    </DockPanel>
                </StackPanel>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

[XML]$ButtonXaml = @"
<Button xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="Auto" Height="30" FontFamily="Segui" FontSize="16" Background="Transparent" Foreground="White" BorderThickness="1" Margin="10" Padding="20,0,20,0" HorizontalAlignment="Right" Cursor="Hand"/>
"@

[XML]$ButtonTextXaml = @"
<TextBlock xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" FontFamily="$($PSBoundParameters.FontFamily)" FontSize="16" Background="Transparent" Foreground="$($PSBoundParameters.ButtonTextForeground)" Padding="20,5,20,5" HorizontalAlignment="Center" VerticalAlignment="Center"/>
"@

[XML]$ContentTextXaml = @"
<TextBlock xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Text="$Content" Foreground="$($PSBoundParameters.ContentTextForeground)" DockPanel.Dock="Right" HorizontalAlignment="Center" VerticalAlignment="Center" FontFamily="$($PSBoundParameters.FontFamily)" FontSize="$ContentFontSize" FontWeight="$($PSBoundParameters.ContentFontWeight)" TextWrapping="Wrap" Height="Auto" MaxWidth="500" MinWidth="50" Padding="10"/>
"@

    # Load the window from XAML
    $Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))

    # Custom function to add a button
    Function Add-Button {
        Param($Content)
        $Button = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $ButtonXaml))
        $ButtonText = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $ButtonTextXaml))
        $ButtonText.Text = "$Content"
        $Button.Content = $ButtonText
        $Button.Add_MouseEnter({
            $This.Content.FontSize = "17"
        })
        $Button.Add_MouseLeave({
            $This.Content.FontSize = "16"
        })
        $Button.Add_Click({
            New-Variable -Name WPFMessageBoxOutput -Value $($This.Content.Text) -Option ReadOnly -Scope Script -Force
            $Window.Close()
        })
        $Window.FindName('ButtonHost').AddChild($Button)
    }

    # Add buttons
    If ($ButtonType -eq "OK")
    {
        Add-Button -Content "OK"
    }

    If ($ButtonType -eq "OK-Cancel")
    {
        Add-Button -Content "OK"
        Add-Button -Content "Cancel"
    }

    If ($ButtonType -eq "Abort-Retry-Ignore")
    {
        Add-Button -Content "Abort"
        Add-Button -Content "Retry"
        Add-Button -Content "Ignore"
    }

    If ($ButtonType -eq "Yes-No-Cancel")
    {
        Add-Button -Content "Yes"
        Add-Button -Content "No"
        Add-Button -Content "Cancel"
    }

    If ($ButtonType -eq "Yes-No")
    {
        Add-Button -Content "Yes"
        Add-Button -Content "No"
    }

    If ($ButtonType -eq "Retry-Cancel")
    {
        Add-Button -Content "Retry"
        Add-Button -Content "Cancel"
    }

    If ($ButtonType -eq "Cancel-TryAgain-Continue")
    {
        Add-Button -Content "Cancel"
        Add-Button -Content "TryAgain"
        Add-Button -Content "Continue"
    }

    If ($ButtonType -eq "None" -and $CustomButtons)
    {
        Foreach ($CustomButton in $CustomButtons)
        {
            Add-Button -Content "$CustomButton"
        }
    }

    # Remove the title bar if no title is provided
    If ($Title -eq "")
    {
        $TitleBar = $Window.FindName('TitleBar')
        $Window.FindName('StackPanel').Children.Remove($TitleBar)
    }

    # Add the Content
    If ($Content -is [String])
    {
        # Replace double quotes with single to avoid quote issues in strings
        If ($Content -match '"')
        {
            $Content = $Content.Replace('"',"'")
        }
        
        # Use a text box for a string value...
        $ContentTextBox = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $ContentTextXaml))
        $Window.FindName('ContentHost').AddChild($ContentTextBox)
    }
    Else
    {
        # ...or add a WPF element as a child
        Try
        {
            $Window.FindName('ContentHost').AddChild($Content) 
        }
        Catch
        {
            $_
        }        
    }

    # Enable window to move when dragged
    $Window.FindName('Grid').Add_MouseLeftButtonDown({
        $Window.DragMove()
    })

    # Activate the window on loading
    If ($OnLoaded)
    {
        $Window.Add_Loaded({
            $This.Activate()
            Invoke-Command $OnLoaded
        })
    }
    Else
    {
        $Window.Add_Loaded({
            $This.Activate()
        })
    }
    

    # Stop the dispatcher timer if exists
    If ($OnClosed)
    {
        $Window.Add_Closed({
            If ($DispatcherTimer)
            {
                $DispatcherTimer.Stop()
            }
            Invoke-Command $OnClosed
        })
    }
    Else
    {
        $Window.Add_Closed({
            If ($DispatcherTimer)
            {
                $DispatcherTimer.Stop()
            }
        })
    }
    

    # If a window host is provided assign it as the owner
    If ($WindowHost)
    {
        $Window.Owner = $WindowHost
        $Window.WindowStartupLocation = "CenterOwner"
    }

    # If a timeout value is provided, use a dispatcher timer to close the window when timeout is reached
    If ($Timeout)
    {
        $Stopwatch = New-object System.Diagnostics.Stopwatch
        $TimerCode = {
            If ($Stopwatch.Elapsed.TotalSeconds -ge $Timeout)
            {
                $Stopwatch.Stop()
                $Window.Close()
            }
        }
        $DispatcherTimer = New-Object -TypeName System.Windows.Threading.DispatcherTimer
        $DispatcherTimer.Interval = [TimeSpan]::FromSeconds(1)
        $DispatcherTimer.Add_Tick($TimerCode)
        $Stopwatch.Start()
        $DispatcherTimer.Start()
    }

    # Play a sound
    If ($($PSBoundParameters.Sound))
    {
        $SoundFile = "$env:SystemDrive\Windows\Media\$($PSBoundParameters.Sound).wav"
        $SoundPlayer = New-Object System.Media.SoundPlayer -ArgumentList $SoundFile
        $SoundPlayer.Add_LoadCompleted({
            $This.Play()
            $This.Dispose()
        })
        $SoundPlayer.LoadAsync()
    }

    # Display the window
    $null = $window.Dispatcher.InvokeAsync{$window.ShowDialog()}.Wait()

    }
}

function Show-WarningMessage {
    param (
        $Text
    )

    $TextBlock = New-Object System.Windows.Controls.TextBlock
    $TextBlock.Text = $Text
    $TextBlock.Padding = 10
    $TextBlock.FontFamily = "Verdana"
    $TextBlock.FontSize = 16
    $TextBlock.VerticalAlignment = "Center"
    
    $StackPanel = New-Object System.Windows.Controls.StackPanel
    $StackPanel.Orientation = "Horizontal"
    $StackPanel.AddChild($TextBlock)
    
    New-WPFMessageBox -Content $StackPanel -Title "WARNING" -TitleFontSize 28 -TitleBackground Orange
}

function Get-CFBundleName {
    param (
        $packagePath
    )

    #Check if 7-zip is installed
    $checkInstall = (gp HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*).DisplayName -Match "7-zip"

    if (!$checkInstall){
        $message = "7-zip is not installed, provide CFBundleShortVersion manually"
        Write-Host -ForegroundColor Yellow $message
        Show-WarningMessage -Text $message
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
                $plistContent =  ($(Get-Content .\Info.plist -Raw) -split "<key>" | Where-Object {$_ -match 'CFBundleName'}).ToString()
                $trimContent = $plistContent.Trim()
                $nameString = $trimContent.Split()
                $nameString = $nameString.Trim() -ne ""
                $name = $nameString[1].Replace('<string>', "").Replace('</string>', "")
                $Script:CFBundleName = $name.ToString()
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
                $plistContent =  ($(Get-Content .\Info.plist -Raw) -split "<key>" | Where-Object {$_ -match 'CFBundleName'}).ToString()
                $trimContent = $plistContent.Trim()
                $nameString = $trimContent.Split()
                $nameString = $nameString.Trim() -ne ""
                $name = $nameString[1].Replace('<string>', "").Replace('</string>', "")
                $Script:CFBundleName = $name.ToString()
                Remove-Item .\Info.plist -Force
                Remove-Item .\Payload~ -Force
            }
        }
    }

    if (!$CFBundleName){
        Write-Host -ForegroundColor Yellow "Unable to extract CFBundleName for $packagePath"
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

#--------------------------------------------------------------------------#
# Add timer for upload jobs
#--------------------------------------------------------------------------#
$JobTrackerList = New-Object System.Collections.ArrayList
$timerJobTracker = New-Object System.Windows.Forms.Timer 
$timerJobTracker.add_Tick({ Update-JobTracker }) 
$timerJobTracker.Enabled = $true 
$timerJobTracker.Start() 

#--------------------------------------------------------------------------#
# Import modules and connect to Azure and Graph
#--------------------------------------------------------------------------#
Import-Module Az.Storage | out-null
Import-Module Microsoft.Graph.Authentication | out-null

Connect-AzAccount | out-null
Connect-MGGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"
Select-MgProfile -Name "beta"

$staccount = Get-AzStorageAccount

if($staccount.count -gt 1){

    for($i = 0; $i -lt $staccount.count; $i++)
    {
        Write-Host -ForegroundColor Cyan "$i`: $($staccount.StorageAccountName[$i])"
    }
    Write-Host -ForegroundColor Yellow "Which storagea account do you want to use to create context? (enter the index of the account)"
    $sta = Read-Host

    $key = Get-AzStorageAccountKey -Name $staccount.StorageAccountName[$sta] -ResourceGroupName $staccount.ResourceGroupName[$sta] | select-object -First 1 -ExpandProperty Value
    $ctx = New-AzStorageContext -StorageAccountName $staccount.StorageAccountName[$sta] -StorageAccountKey $key
    $containers = Get-AzStorageContainer -Context $ctx
    $WPFsearchgroup.IsEnabled = $false

}

else{
$key = Get-AzStorageAccountKey -Name $staccount.StorageAccountName -ResourceGroupName $staccount.ResourceGroupName | select-object -First 1 -ExpandProperty Value
$ctx = New-AzStorageContext -StorageAccountName $staccount.StorageAccountName -StorageAccountKey $key
$containers = Get-AzStorageContainer -Context $ctx
$WPFsearchgroup.IsEnabled = $false
}

#--------------------------------------------------------------------------#
# Theme switcher
#--------------------------------------------------------------------------#
$WPFThemeSwitcher.Add_Click({
    $Theme = [ControlzEx.Theming.ThemeManager]::Current.DetectTheme($form)
    $baseColor = ($Theme.BaseColorScheme)
    if ($baseColor -eq "Light"){
        [ControlzEx.Theming.ThemeManager]::Current.ChangeThemeBaseColor($form,"Dark")
        $WPFgrid.AlternatingRowBackground = "SteelBlue"
    }
    elseif ($baseColor -eq "Dark"){
        [ControlzEx.Theming.ThemeManager]::Current.ChangeThemeBaseColor($form,"Light")
        $WPFgrid.AlternatingRowBackground = "LightBlue"
    }
})

#--------------------------------------------------------------------------#
# Assign packages to group
#--------------------------------------------------------------------------#
$WPFsearchgroup.Add_Click({

    if($WPFtabcontrol.SelectedItem.Header -eq "New"){
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
        else {
            Show-WarningMessage -Text "Could not find group, try again!"
        }
    }

    elseif ($WPFtabcontrol.SelectedItem.Header -eq "Update"){
        $Script:group = Get-MgGroup -Filter "displayName eq '$($WPFgroupname.Text)'"
        if ($group){
            $WPFgrouperror.Visibility = "Hidden"
            $WPFupdatepackagegrid.Columns[0].Visibility = "Visible"
            $items = $WPFupdatepackagegrid.Items
            [System.Collections.ArrayList]$itemsArray = @()
            $itemsArray += $WPFupdatepackagegrid.ItemsSource
            $itemsArray | Add-Member -MemberType NoteProperty -Name AssignTo -Value $group.DisplayName -force
            $WPFupdatepackagegrid.ItemsSource = $itemsArray
        }
        else {
            Show-WarningMessage -Text "Could not find group, try again!"
        }
    }

})

#==================================================================================================================================================================#
# New package tab
#==================================================================================================================================================================#

#--------------------------------------------------------------------------#
# Disable buttons until folder is selected
#--------------------------------------------------------------------------#
$WPFaddpackage.IsEnabled = $false
$WPFremovepackage.IsEnabled = $false

#--------------------------------------------------------------------------#
# Populate ComboBox with Storage Account, Resource Groups and Container
#--------------------------------------------------------------------------#
foreach ($account in $staccount.StorageAccountName){
    $WPFstaccbox.Items.Add($account) | out-null
}

foreach ($rsgroup in $staccount.ResourceGroupName){
    $WPFrsgroupbox.Items.Add($rsgroup) | out-null
}

foreach ($container in $containers.Name){
    $WPFcontainerbox.Items.Add($container) | out-null
}

#--------------------------------------------------------------------------#
# Select folder button action
#--------------------------------------------------------------------------#                                           
$WPFbutton.Add_Click({

    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $null = $browser.ShowDialog()

    $itemsArray = @()  
    $packages = Get-ChildItem $browser.SelectedPath | where {$_.Name -like "*.pkg" -or $_.Name -like "*.dmg"}

    foreach ($package in $packages){
        
        Get-CFBundleName -packagePath $package.FullName

        if ($CFBundleName){
            $array = @([pscustomobject]@{AppName=$CFBundleName; `
                                         App="$($CFBundleName).app"; `
                                         ProcessPath="/Applications/$($CFBundleName).app/Contents/MacOS/$($CFBundleName)"; `
                                         TerminateProcess="false"; `
                                         Autoupdate="false"; `
                                         FullName=$package.FullName; `
                                         FileName=$package.Name})
            $itemsArray += $array
        }
        else{
            $message = "Unable to get CFBundleName for $($package.Name), skipping package"
            Write-Host -ForegroundColor Yellow $message
            Show-WarningMessage -Text $message
        }
    }
    
    $WPFgrid.ItemsSource = $itemsArray

    $WPFaddpackage.IsEnabled = $true
    $WPFremovepackage.IsEnabled = $true
    $WPFsearchgroup.IsEnabled = $true

})

#--------------------------------------------------------------------------#
# Remove package from datagrid
#--------------------------------------------------------------------------#
$WPFremovepackage.Add_Click({

    $removeItem = $WPFgrid.SelectedItem
    [System.Collections.ArrayList]$itemsArray = @()
    $itemsArray += $WPFgrid.ItemsSource

    $itemsArray.Remove($removeItem)

    $WPFgrid.ItemsSource = $itemsArray

})

#--------------------------------------------------------------------------#
# Upload package button actions
#--------------------------------------------------------------------------#
$WPFaddpackage.Add_Click({

    if ((!$WPFstaccbox.SelectedValue) -or (!$WPFrsgroupbox.SelectedValue) -or (!$WPFcontainerbox.SelectedValue)){
        
        $WPFtextNull.Visibility = "Visible" 

    }

    else {

        Write-Host -ForegroundColor Cyan "#-------------------------------------------------------------#"
        Write-Host -ForegroundColor Cyan "New packages"
        Write-Host -ForegroundColor Cyan "#-------------------------------------------------------------#"

        Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
        Write-Host -ForegroundColor DarkGray "Uploading packages"
        Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
        
        foreach ($item in $WPFgrid.Items | where {$_.App -and $_.AppName -and $_.ProcessPath}){

             $blob = Get-AzStorageBlob -Context $ctx -Blob $item.FileName -Container $WPFcontainerbox.SelectedValue -ErrorAction SilentlyContinue
        
             #Check if blob exists
             if ($blob){
                Write-Host -ForegroundColor Yellow "#-------------------------------------------------------------#"
                Write-Host -ForegroundColor Yellow "Blob already exists for $($item.FileName), skipping"
                Write-Host -ForegroundColor Yellow "#-------------------------------------------------------------#"
             }

             else {

                $staccboxValue = $WPFstaccbox.SelectedValue
                $rsgroupboxValue = $WPFrsgroupbox.SelectedValue
                $containerboxvalue = $WPFcontainerbox.SelectedValue
                $fileName = $item.FullName
                $blobName = $item.FileName

                try {
                        $JobScript = {
                            param(
                                $staccboxValue,
                                $rsgroupboxValue,
                                $containerboxvalue,
                                $fileName,
                                $blobName
                            )
                            
                            $key = Get-AzStorageAccountKey `
                            -Name $staccboxValue `
                            -ResourceGroupName $rsgroupboxValue `
                            | select-object -First 1 -ExpandProperty Value
                            $ctx = New-AzStorageContext `
                            -StorageAccountName $staccboxValue `
                            -StorageAccountKey $key

                            $ProgressPreference = "SilentlyContinue"

                            $upload = Set-AzStorageBlobContent `
                            -Container $containerboxvalue `
                            -File $fileName `
                            -Blob $blobName `
                            -Context $ctx `
                            
                        }
                        $UpdateScript = {
                            Param($Job)
                            $results = Receive-Job -Job $Job -Keep
                            $WPFBadge1.Badge = "Uploading"
                                
                        }
                        $CompletedScript = {
                            Param($Job)
                            $results = Receive-Job -Job $Job
                            $WPFBadge1.Badge = $null
                            Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                            Write-Host -ForegroundColor DarkGray "Upload finished"
                            Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                                
                        }

                        Add-JobTracker -Name "UploadLOB" `
                        -JobScript $JobScript `
                        -UpdateScript $UpdateScript `
                        -CompletedScript $CompletedScript `
                        -ArgumentList $staccboxValue,$rsgroupboxValue,$containerboxvalue,$fileName,$blobName
                    }

                    catch{
                        $message = "Failed to create upload job"
                        Write-Host -ForegroundColor Yellow $message
                        Show-WarningMessage -Text $message
                        break
                    }

                try {
                    Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                    Write-Host -ForegroundColor DarkGray "Adding install script parameters for $($item.AppName)"
                    Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                    $scriptName = "MACLAT-install$($item.AppName).sh"
                    Copy-Item ".\Scripts\installapp.sh" ".\Scripts\$scriptName" | out-null
                    $scriptContent = Get-Content ".\Scripts\$scriptName" -raw
                            
                    (($scriptContent) -replace 'weburl=""', "weburl=""https://$($WPFstaccbox.SelectedValue).blob.core.windows.net/$($WPFcontainerbox.SelectedValue)/$($item.FileName)"" " `
                                    -replace 'appname=""', "appname=""$($item.AppName)"" " `
                                    -replace 'app=""', "app=""$($item.App)"" " `
                                    -replace 'logandmetadir=""', "logandmetadir=""/Library/Logs/Microsoft/IntuneScripts/MACLAT-install$($item.AppName)"" " `
                                    -replace 'processpath=""', "processpath=""$($item.ProcessPath)"" " `
                                    -replace 'terminateprocess=""', "terminateprocess=""$($item.TerminateProcess)"" " `
                                    -replace 'autoupdate=""', "autoupdate=""$($item.Autoupdate)"" ") `
                                    | Set-Content -Path ".\Scripts\$scriptName"

                    }
                    catch {
                        $message = "Failed to set script parameters"
                        Write-Host -ForegroundColor Yellow $message
                        Show-WarningMessage -Text $message
                        break
                    }

                try {
                    $script = (Get-Content ".\Scripts\$scriptName" -raw) -replace "`r`n","`n"
                    $scriptContent = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
                }

                catch{
                    $message = "Failed to get script content"
                    Write-Host -ForegroundColor Yellow $message
                    Show-WarningMessage -Text $message
                    break
                }

                #Check if script already exists

                $getScriptRequest = Invoke-MGGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts?`$filter=startswith(displayName,'$scriptName')"

                if($getScriptRequest.Value){
                    Write-Host -ForegroundColor Yellow "#-------------------------------------------------------------#"
                    Write-Host -ForegroundColor Yellow "$($item.AppName) install script already exists, skipping"
                    Write-Host -ForegroundColor Yellow "#-------------------------------------------------------------#"
                }

                else{

                try {
                    Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                    Write-Host -ForegroundColor DarkGray "Adding $($item.AppName) install script to MEM"
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
                    $message = "Failed to add scripts to MEM"
                    Write-Host -ForegroundColor Yellow $message
                    Show-WarningMessage -Text $message
                    break
                }

                try {
                    if ($group){
                        Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                        Write-Host -ForegroundColor DarkGray "Assigning $($item.AppName) to group $($group.DisplayName)"
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
                    $message = "Failed to assign script"
                    Write-Host -ForegroundColor Yellow $message
                    Show-WarningMessage -Text $message
                }

            }
        }            

        }

    }

})

#==================================================================================================================================================================#
# Update package tab
#==================================================================================================================================================================#

#--------------------------------------------------------------------------#
# Disable buttons until file is selected
#--------------------------------------------------------------------------#
$WPFupdatebutton.IsEnabled = $false

#--------------------------------------------------------------------------#
# Select file button action
#--------------------------------------------------------------------------#                                           
$WPFupdatepackagebutton.Add_Click({

    $browser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
    }
    $null = $browser.ShowDialog()

    $itemsArray = @()  
    $package = Get-ChildItem $browser.FileName
        
    Get-CFBundleName -packagePath $package.FullName

    if ($CFBundleName){
        $array = @([pscustomobject]@{AppName=$CFBundleName; `
                                     App="$($CFBundleName).app"; `
                                     ProcessPath="/Applications/$($CFBundleName).app/Contents/MacOS/$($CFBundleName)"; `
                                     TerminateProcess="false"; `
                                     Autoupdate="false"; `
                                     FullName=$package.FullName; `
                                     FileName=$package.Name})
        $itemsArray += $array
    }

    else{
        $message = "Unable to get CFBundleName for $($package.Name), skipping package"
        Write-Host -ForegroundColor Yellow $message
        Show-WarningMessage -Text $message
    }
    
    $WPFupdatepackagegrid.ItemsSource = $itemsArray
    $WPFsearchgroup.IsEnabled = $true
    $WPFupdatebutton.IsEnabled = $true

})

#--------------------------------------------------------------------------#
# Get package button action
#--------------------------------------------------------------------------#                                             
$WPFgetpackagesbutton.Add_Click({
    
    $blobs = Get-AzStorageBlob -Container $WPFcontainerbox.SelectedValue -Context $ctx -ErrorAction SilentlyContinue

    foreach ($blob in $blobs.Name){
        $WPFpackagesbox.Items.Add($blob) | out-null
    }

})

#--------------------------------------------------------------------------#
# Update package button action
#--------------------------------------------------------------------------#

$WPFupdatebutton.Add_Click({

    Write-Host -ForegroundColor Cyan "#-------------------------------------------------------------#"
    Write-Host -ForegroundColor Cyan "Update packages"
    Write-Host -ForegroundColor Cyan "#-------------------------------------------------------------#"

    Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
    Write-Host -ForegroundColor DarkGray "Updating $($WPFpackagesbox.SelectecValue)"
    Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"

    [PSCustomObject]$updateItem = $WPFupdatepackagegrid.Items
    $blob = Get-AzStorageBlob -Context $ctx -Blob $WPFpackagesbox.SelectedValue -Container $WPFcontainerbox.SelectedValue -ErrorAction SilentlyContinue

    $currentScript = Invoke-MGGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts?`$filter=startswith(displayName,'MACLAT-install$($updateItem.AppName).sh')"
    $scriptPath = ".\Scripts\$($currentScript.Value.displayName)"

    if($currentScript){
        #$scriptToUpdate = Invoke-MGGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts/$($scriptToUpdate.id)"
        Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
        Write-Host -ForegroundColor DarkGray "Adding install script parameters for $($updateItem.AppName)"
        Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"

        try{
            $scriptContent = (Invoke-MGGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts/$($currentScript.Value.id)").scriptContent
            $script = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($scriptContent))
            $script | Out-File $scriptPath
            $scriptContent = Get-Content $scriptPath

            (($scriptContent) -replace 'weburl=".*"', "weburl=""https://$($WPFstaccbox.SelectedValue).blob.core.windows.net/$($WPFcontainerbox.SelectedValue)/$($updateItem.FileName)"" " `
            -replace 'appname=".*"', "appname=""$($updateItem.AppName)"" " `
            -replace 'app=".*"', "app=""$($updateItem.App)"" " `
            -replace 'logandmetadir=".*"', "logandmetadir=""/Library/Logs/Microsoft/IntuneScripts/MACLAT-install$($updateItem.AppName)"" " `
            -replace 'processpath=".*"', "processpath=""$($updateItem.ProcessPath)"" " `
            -replace 'terminateprocess=".*"', "terminateprocess=""$($updateItem.TerminateProcess)"" " `
            -replace 'autoupdate=".*"', "autoupdate=""$($updateItem.Autoupdate)"" ") `
            | Set-Content -Path $scriptPath

        }
        catch{
            $message = "Failed to set script parameters"
            Write-Host -ForegroundColor Yellow $message
            Show-WarningMessage -Text $message
            break
        }

        try{
            $script = (Get-Content $scriptPath -raw) -replace "`r`n","`n"
            $scriptContent = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
        }
        catch{
            $message = "Failed to get script content"
            Write-Host -ForegroundColor Yellow $message
            Show-WarningMessage -Text $message
            break
        }

        if($WPFremovecheck.IsChecked){
            try{
                Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                Write-Host -ForegroundColor DarkGray "Removing blob $($blob.Name)"
                Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"

                $removeBlob =  Remove-AzStorageBlob -Context $ctx -Blob $blob.Name -Container $WPFcontainerbox.SelectedValue
            }
            catch{
                $message = "Failed to remove blob $($blob.Name)"
                Write-Host -ForegroundColor Yellow $message
                Show-WarningMessage -Text $message
                break
            }
        }

        try {
            Write-Host -ForegroundColor DarkGray "#------------------------------------------------------------------#"
            Write-Host -ForegroundColor DarkGray "Updating $($updateItem.AppName) install script with new parameters in MEM"
            Write-Host -ForegroundColor DarkGray "#------------------------------------------------------------------#"
            $RequestBodyObject = @{
                "@odata.type" = "#microsoft.graph.deviceShellScript"
                retryCount = 3
                blockExecutionNotifications = $false
                displayName = $currentScript.Value.displayName
                scriptContent = $scriptContent
                fileName = $currentScript.Value.displayName
            }

            $body = $RequestBodyObject | ConvertTo-Json

            $updateScriptRequest = Invoke-MGGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts/$($currentScript.Value.id)" -Body $body -ContentType 'application/json'
            Remove-Item $scriptPath -Force
        }
        catch{
            $message = "Failed to update script in MEM"
            Write-Host -ForegroundColor Yellow $message
            Show-WarningMessage -Text $message
            break
        }

        $staccboxValue = $WPFstaccbox.SelectedValue
        $rsgroupboxValue = $WPFrsgroupbox.SelectedValue
        $containerboxvalue = $WPFcontainerbox.SelectedValue
        $fileName = $updateItem.FullName
        $blobName = $updateItem.FileName

        try {
            Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
            Write-Host -ForegroundColor DarkGray "Uploading $($updateItem.FileName)"
            Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"

                $JobScript = {
                    param(
                        $staccboxValue,
                        $rsgroupboxValue,
                        $containerboxvalue,
                        $fileName,
                        $blobName
                    )
                    
                    $key = Get-AzStorageAccountKey `
                    -Name $staccboxValue `
                    -ResourceGroupName $rsgroupboxValue `
                    | select-object -First 1 -ExpandProperty Value
                    $ctx = New-AzStorageContext `
                    -StorageAccountName $staccboxValue `
                    -StorageAccountKey $key

                    $ProgressPreference = "SilentlyContinue"

                    $upload = Set-AzStorageBlobContent `
                    -Container $containerboxvalue `
                    -File $fileName `
                    -Blob $blobName `
                    -Context $ctx `
                    
                }
                $UpdateScript = {
                    Param($Job)
                    $results = Receive-Job -Job $Job -Keep
                    $WPFBadge1.Badge = "Uploading"
                        
                }
                $CompletedScript = {
                    Param($Job)
                    $results = Receive-Job -Job $Job
                    $WPFBadge1.Badge = $null
                    Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                    Write-Host -ForegroundColor DarkGray "Upload finished"
                    Write-Host -ForegroundColor DarkGray "#-------------------------------------------------------------#"
                        
                }

                Add-JobTracker -Name "UploadLOB" `
                -JobScript $JobScript `
                -UpdateScript $UpdateScript `
                -CompletedScript $CompletedScript `
                -ArgumentList $staccboxValue,$rsgroupboxValue,$containerboxvalue,$fileName,$blobName
            }
            catch{
                $message = "Failed to create upload job"
                Write-Host -ForegroundColor Yellow $message
                Show-WarningMessage -Text $message
                break
            }

    }

})

#--------------------------------------------------------------------------#
# Show form
#--------------------------------------------------------------------------#
$Form.ShowDialog() | out-null
