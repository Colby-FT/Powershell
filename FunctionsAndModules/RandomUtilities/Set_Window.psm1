function Set-Window {
    <#
    .SYNOPSIS
    Snap Window to Left, Right, Top, or Bottom

    .EXAMPLE
    Set-Window -Position Left
    Snaps the PS window to the left side of the screen
    #>
    
    [CmdletBinding()]
    param (
        [ValidateSet("Left", "Right", "Top", "Bottom")]
        [string]$Position
    )
    
    Begin {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public class User32 {
            [DllImport("user32.dll")]
            public static extern IntPtr GetForegroundWindow();
            [DllImport("user32.dll")]
            public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
            [DllImport("user32.dll")]
            public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
            public struct RECT {
                public int Left;
                public int Top;
                public int Right;
                public int Bottom;
            }
        }
"@
    }
    
    Process {
        $hwnd = [User32]::GetForegroundWindow()
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

        switch ($Position) {
            "Left" {
                [User32]::MoveWindow($hwnd, 0, 0, $screen.Width / 2, $screen.Height, $true)
            }
            "Right" {
                [User32]::MoveWindow($hwnd, $screen.Width / 2, 0, $screen.Width / 2, $screen.Height, $true)
            }
            "Top" {
                [User32]::MoveWindow($hwnd, 0, 0, $screen.Width, $screen.Height / 2, $true)
            }
            "Bottom" {
                [User32]::MoveWindow($hwnd, 0, $screen.Height / 2, $screen.Width, $screen.Height / 2, $true)
            }
        }
    }
}