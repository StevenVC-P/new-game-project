# New Game Project

## Local Godot Validation

This project includes a Windows-friendly PowerShell check script:

```powershell
.\scripts\check-godot.ps1
```

Configure the Godot executable without adding it to PATH by setting `GODOT_EXE`:

```powershell
$env:GODOT_EXE = "C:\Path\To\Godot_v4.6.exe"
.\scripts\check-godot.ps1
```

You can also pass the path directly:

```powershell
.\scripts\check-godot.ps1 -GodotExe "C:\Path\To\Godot_v4.6.exe"
```

Optional local convenience: create a `.godot-exe` file in the project root with one line containing the full path to your Godot executable. The script uses that file if `GODOT_EXE` is not set.

The script runs Godot directly in headless editor mode against this project root, so Godot does not need to be globally installed or available on PATH.
