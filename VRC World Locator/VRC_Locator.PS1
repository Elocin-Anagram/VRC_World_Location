# VRChat World Logger with Enhanced Execution Policy Check
# This script continuously monitors the VRChat log file to extract the current world name and instance type.
# It first checks if the execution policy is set to 'RemoteSigned' to prevent errors.

# --- Execution Policy Check ---
# Check if the current session is running as Administrator.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$currentPolicy = Get-ExecutionPolicy -Scope LocalMachine
Write-Host "Current Execution Policy for LocalMachine is: $currentPolicy"

# If the policy is not 'RemoteSigned', handle the situation based on admin privileges.
if ($currentPolicy -ne 'RemoteSigned') {
    if ($isAdmin) {
        # If the user is an admin, prompt to set the policy automatically.
        $choice = Read-Host "Execution policy 'RemoteSigned' is required. Would you like to set it now? (Y/N)"
        if ($choice -eq 'y' -or $choice -eq 'Y') {
            Write-Host "Setting Execution Policy to 'RemoteSigned'..." -ForegroundColor Cyan
            Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force | Out-Null
            Write-Host "Execution Policy set successfully." -ForegroundColor Green
        } else {
            Write-Host "Execution Policy was not changed. The script cannot proceed." -ForegroundColor Yellow
            Read-Host "Press Enter to exit..."
            exit
        }
    } else {
        # If the user is not an admin, provide instructions and exit with a pause.
        Write-Host "Execution policy 'RemoteSigned' is required to run this script." -ForegroundColor Yellow
        Write-Host "Please open PowerShell as an Administrator and run this script again to set the policy." -ForegroundColor Yellow
        Read-Host "Press Enter to exit..."
        # Exit the script to prevent it from running with an incorrect policy.
        exit
    }
}

Write-Host "Execution Policy check passed. Starting the VRChat World Logger..." -ForegroundColor Green

# --- VRChat Log Monitoring Loop ---
# This is a perpetual loop that runs every 15 seconds.
while ($true) {

    # Define the VRChat log directory path using the correct "LocalLow" directory.
    $logDirectory = "$env:USERPROFILE\AppData\LocalLow\VRChat\VRChat"

    # Define the output file path.
    $outputFile = "VRChat_Current_World.txt"

    # Get the most recent log file.
    $latestLogFile = Get-ChildItem -Path $logDirectory -Filter "output_log_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    # Check if a log file was found.
    if ($null -eq $latestLogFile) {
        Write-Output "No VRChat log files found at '$logDirectory'. Waiting 15 seconds before checking again..."
    } else {
        # Read the last 10000 lines of the log file for efficiency.
        $logContent = Get-Content -Path $latestLogFile.FullName -Tail 10000

        # Find the latest "Joining or Creating Room" entry for the world name.
        $roomEntry = $logContent | Select-String -Pattern "\[Behaviour\] Joining or Creating Room: " | Select-Object -Last 1
        
        # Find the latest "Destination fetching" entry for the instance type and ID.
        $destinationEntry = $logContent | Select-String -Pattern "\[Behaviour\] Destination fetching: " | Select-Object -Last 1

        if ($null -ne $destinationEntry -and $null -ne $roomEntry) {
            # Extract the world name using a regular expression.
            $worldName = "Unknown World"
            if ($roomEntry.ToString() -match '\[Behaviour\] Joining or Creating Room: (.*)') {
                $worldName = $matches[1].Trim()
            }

            # Extract the full destination URL from the log entry.
            $destinationInfo = $destinationEntry.ToString()
            $instanceType = "Public"
            $groupId = ""
            $ageGate = ""

            # Check for a group instance and extract the ID and type.
            if ($destinationInfo -match 'group\((grp_[a-zA-Z0-9-]+)\)') {
                $groupId = $matches[1]
                # Check for the specific group access type.
                if ($destinationInfo -match 'groupAccessType\(public\)') {
                    $instanceType = "Group Public"
                } elseif ($destinationInfo -match 'groupAccessType\(plus\)') {
                    $instanceType = "Group Plus"
                } elseif ($destinationInfo -match 'groupAccessType\(members\)') {
                    $instanceType = "Group Members"
                } else {
                    $instanceType = "Group" # Default to 'Group' if type is not specified.
                }
            }
            # Check for other common instance types, including the "hidden" Friends+ type.
            elseif ($destinationInfo -match 'friends\+') {
                $instanceType = "Friends+"
            }
            elseif ($destinationInfo -match '~hidden') {
                $instanceType = "Friends+"
            }
            elseif ($destinationInfo -match 'friends') {
                $instanceType = "Friends"
            }
            elseif ($destinationInfo -match 'invite\+') {
                $instanceType = "Invite+"
            }
            elseif ($destinationInfo -match '~canRequestInvite') {
                $instanceType = "Invite+"
            }
            elseif ($destinationInfo -match 'private') {
                $instanceType = "Invite"
            }
            
            # Check for an age-gated instance.
            if ($destinationInfo -match '~ageGate') {
                $ageGate = " 18+"
            }

            # Create a clean output string.
            $outputString = "$worldName`n($instanceType$ageGate"
            if ($groupId) {
                $outputString += ", $groupId)"
            } else {
                $outputString += ")"
            }

            # Check if the output has changed before writing to avoid excessive file updates.
            $currentOutputInFile = Get-Content -Path $outputFile -ErrorAction SilentlyContinue
            if ($currentOutputInFile -ne $outputString) {
                Set-Content -Path $outputFile -Value $outputString
                Write-Host "New world information found and saved to '$outputFile'."
                Write-Host "Output:"
                Write-Host $outputString
            }
        } else {
            # If no world entries are found, it's likely a fresh log file.
            Write-Output "No world name or instance entry found in the latest log file. Waiting for new entries..."
        }
    }

    # Pause the script for 15 seconds before the next loop iteration.
    Start-Sleep -Seconds 15
}
