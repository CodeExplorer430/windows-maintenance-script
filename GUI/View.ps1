<#
.SYNOPSIS
    GUI View Construction for the Windows Maintenance Framework (WPF Edition).
#>

Add-Type -AssemblyName PresentationFramework

function Get-MaintenanceView {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]

    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Theme,

        [Parameter(Mandatory=$true)]
        [hashtable]$Fonts
    )

    # Define XAML with DynamicResource for theming
    [xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows Maintenance Framework v4.2.0" Height="800" Width="1000"
        WindowStartupLocation="CenterScreen"
        Background="{DynamicResource Brush_Background}"
        Foreground="{DynamicResource Brush_Foreground}"
        FontFamily="{DynamicResource Font_Header}">
    <Window.Resources>
        <!-- Styles -->
        <Style TargetType="Button">
            <Setter Property="Background" Value="{DynamicResource Brush_ControlBg}"/>
            <Setter Property="Foreground" Value="{DynamicResource Brush_Foreground}"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="14"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{DynamicResource Brush_ControlHover}"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="{DynamicResource Brush_Foreground}"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="FontSize" Value="14"/>
        </Style>
        <Style TargetType="Label">
            <Setter Property="Foreground" Value="{DynamicResource Brush_Foreground}"/>
            <Setter Property="FontSize" Value="14"/>
        </Style>
        <Style TargetType="GroupBox">
            <Setter Property="Foreground" Value="{DynamicResource Brush_Foreground}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Brush_Border}"/>
            <Setter Property="Margin" Value="10"/>
            <Setter Property="Padding" Value="10"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="300"/> <!-- Sidebar -->
            <ColumnDefinition Width="*"/>   <!-- Main Content -->
        </Grid.ColumnDefinitions>

        <!-- Sidebar -->
        <Border Grid.Column="0" Background="{DynamicResource Brush_Panel}" BorderBrush="{DynamicResource Brush_Border}" BorderThickness="0,0,1,0">
            <DockPanel>
                <Label Content="Modules" FontWeight="Bold" FontSize="18" Padding="15" DockPanel.Dock="Top"/>
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="ModuleList" Margin="10">
                        <!-- Module Checkboxes will be added here dynamically by Controller -->
                    </StackPanel>
                </ScrollViewer>
            </DockPanel>
        </Border>

        <!-- Main Content -->
        <Grid Grid.Column="1" Margin="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/> <!-- Header -->
                <RowDefinition Height="Auto"/> <!-- Options -->
                <RowDefinition Height="*"/>    <!-- Console -->
                <RowDefinition Height="Auto"/> <!-- Actions -->
            </Grid.RowDefinitions>

            <!-- Header -->
            <StackPanel Grid.Row="0">
                <Label Content="System Maintenance Dashboard" FontSize="24" FontWeight="Bold"/>
                <Label Name="StatusLabel" Content="Initializing..." Foreground="Gray"/>
            </StackPanel>

            <!-- Options -->
            <GroupBox Header="Execution Options" Grid.Row="1">
                <StackPanel Orientation="Horizontal">
                    <CheckBox Name="CbWhatIf" Content="Simulation Mode (-WhatIf)"/>
                    <CheckBox Name="CbSilent" Content="Silent Mode (No Popups)" Margin="20,5,5,5"/>
                </StackPanel>
            </GroupBox>

            <!-- Console Output -->
            <GroupBox Header="Console Output" Grid.Row="2">
                <TextBox Name="Console"
                         Background="{DynamicResource Brush_Background}"
                         Foreground="{DynamicResource Brush_Foreground}"
                         FontFamily="{DynamicResource Font_Console}"
                         FontSize="12" IsReadOnly="True"
                         VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" BorderThickness="0"/>
            </GroupBox>

            <!-- Action Bar -->
            <Grid Grid.Row="3" Margin="0,10,0,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <ProgressBar Name="Progress" Height="25" Margin="0,0,10,0" Background="{DynamicResource Brush_ControlBg}" Foreground="{DynamicResource Brush_Primary}"/>

                <Button Name="BtnStart" Grid.Column="1" Content="START MAINTENANCE" Width="180" Background="{DynamicResource Brush_Primary}"/>
                <Button Name="BtnStop" Grid.Column="2" Content="STOP" Width="100" Background="{DynamicResource Brush_Error}"/>
            </Grid>
        </Grid>
    </Grid>
</Window>
"@

    # Parse XAML
    $Reader = (New-Object System.Xml.XmlNodeReader $Xaml)
    try {
        $Window = [Windows.Markup.XamlReader]::Load($Reader)
    } catch {
        Throw "Failed to load XAML: $_"
    }

    # Inject Theme Resources
    foreach ($Key in $Theme.Keys) {
        if ($Window.Resources.Contains($Key)) {
            $Window.Resources[$Key] = $Theme[$Key]
        } else {
            $Window.Resources.Add($Key, $Theme[$Key])
        }
    }

    foreach ($Key in $Fonts.Keys) {
         if ($Window.Resources.Contains($Key)) {
            $Window.Resources[$Key] = $Fonts[$Key]
        } else {
            $Window.Resources.Add($Key, $Fonts[$Key])
        }
    }

    # Return Control Map
    return @{
        Window     = $Window
        ModuleList = $Window.FindName("ModuleList")
        Console    = $Window.FindName("Console")
        Progress   = $Window.FindName("Progress")
        StartBtn   = $Window.FindName("BtnStart")
        StopBtn    = $Window.FindName("BtnStop")
        WhatIf     = $Window.FindName("CbWhatIf")
        Silent     = $Window.FindName("CbSilent")
        StatusLabel = $Window.FindName("StatusLabel")
    }
}
