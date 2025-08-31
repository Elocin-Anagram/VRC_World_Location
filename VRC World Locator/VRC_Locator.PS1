# This is a perpetual loop that runs every 60 seconds.
while ($true) {

    # Define the VRChat log directory path using the correct "LocalLow" directory.
    $logDirectory = "$env:USERPROFILE\AppData\LocalLow\VRChat\VRChat"

    # Define the output file path.
    $outputFile = "VRChat_Current_World.txt"

    # Get the most recent log file.
    $latestLogFile = Get-ChildItem -Path $logDirectory -Filter "output_log_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    # Check if a log file was found.
    if ($null -eq $latestLogFile) {
        Write-Output "No VRChat log files found at '$logDirectory'. Waiting 60 seconds before checking again..."
    } else {
        # Read the last 10000 lines of the log file for efficiency.
        $logContent = Get-Content -Path $latestLogFile.FullName -Tail 10000

        # Find the latest "Destination fetching" entry for the instance type.
        $destinationEntry = $logContent | Select-String -Pattern "\[Behaviour\] Destination fetching: " | Select-Object -Last 1
        
        # Find the latest "Joining or Creating Room" entry for the world name.
        $roomEntry = $logContent | Select-String -Pattern "\[Behaviour\] Joining or Creating Room: " | Select-Object -Last 1

        if ($null -ne $destinationEntry -and $null -ne $roomEntry) {
            # Extract the instance type.
            $destinationInfo = $destinationEntry.ToString()
            $instanceType = "Public"
            $groupId = ""

            # Updated regex to capture all known instance types.
            if ($destinationInfo -match '~(private|friends\+|friends|invite\+|invite|group\+|groupAccessType\(public\)|groupAccessType\(plus\)|groupAccessType\(members\))') {
                $match = $destinationInfo | Select-String -Pattern '(private|friends\+|friends|invite\+|invite|group\+|groupAccessType\(public\)|groupAccessType\(plus\)|groupAccessType\(members\))'
                $instanceType = $match.Matches[0].Value
                
                # Assign user-friendly names to instance types.
                if ($instanceType -eq 'groupAccessType(public)') {
                    $instanceType = "Group Public"
                } elseif ($instanceType -eq 'groupAccessType(plus)') {
                    $instanceType = "Group Plus"
                } elseif ($instanceType -eq 'groupAccessType(members)') {
                    $instanceType = "Group Members"
                } elseif ($instanceType -match '\((.*)\)') {
                    $instanceType = $matches[1]
                }
            }

            # Extract the Group ID if it exists.
            if ($destinationInfo -match 'group\((grp_[a-zA-Z0-9-]+)\)') {
                $groupId = $matches[1]
            }
            
            # Use a regular expression to capture the full world name accurately.
            $worldName = "Unknown World"
            if ($roomEntry.ToString() -match '\[Behaviour\] Joining or Creating Room: (.*)') {
                $worldName = $matches[1].Trim()
            }

            # Create a clean output string, including the Group ID if found.
            $outputString = "$worldName`n($instanceType"
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
