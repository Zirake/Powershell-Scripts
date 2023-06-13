<#
.SYNOPSIS
    Take two Directory paths and compare the files in the locations to determine the newest version of the files.

.NOTES
    Author : ---------
    Date : 4/28/2023
    Last Updated : 6/12/2023

.PARAMETER -ReferencePath
    This is the path you want to use to compare with.
.Parameter -DifferencePath
    This is the path you want to use to compare against.
.Parameter -RefDiffPaths
    This will allow you to provide a list of Reference Paths and Difference paths to compare between. It will be a
    linear comparision by default. MUST HAVE HEADERS, you can create a .csv and import-csv to a powershell variable
    and pass it to this parameter. 
    
    Example below:
    $ReferencePath1 will compare to DifferencePath1
    $ReferencePath2 will Compare to DifferencePath2
    $ReferencePath1 will NOT compare to DifferencePath2
.Parameter -OutFile
    This allows you to state a file for all the data to write too. 
.Parameter -MultipleOutFiles
    This is a boolean set field that allows you to have a third column of data containing outfile paths.
.Parameter -Iterations
    Allow you to determine number of sessions you want running to not max out your computer resources.
#>

param
(
    [CmdLetBinding()]
    [Parameter(Mandatory = $true, ParameterSetName = "ComparePaths")][ValidateNotNullOrEmpty()][string]$ReferencePath,
    [Parameter(Mandatory = $true, ParameterSetname = "ComparePaths")][ValidateNotNullOrEmpty()][string]$DifferencePath,
    [Parameter(Mandatory = $true, ParameterSetName = "CompareMultiPaths")][ValidateNotNullOrEmpty()][array]$RefDiffPaths,
    [Parameter(ParameterSetName = "CompareMultiPaths")][switch]$MultipleOutFiles,
    [Parameter()][string]$OutFile,
    [Parameter()][switch]$DisplayOutput,
    [Parameter()][int32]$Iterations = "10"
)
function DisplayErrorMessage([int]$messageIndex, [string]$messageVariable)
{
    $message = switch ($messageIndex)
    {
        0 {return}
        1 { "To many/few Headers, there should Two or Three" }
        2 { "The number of Reference and Destination Items do not match"}
        3 { "$messageVariable is not accessible/does not exist."}
        4 {return "There are no Reference or Difference Files in the path"}
        Default {"Unable to obtain Error Message"}
    }
    Write-Warning $message

    #Exit Routine
    Start-Sleep -Seconds 4
    exit
}

function ResetScreen($seconds)
{
    # Print Current Status Screen
    Clear-Host
    Get-Job

    # Sleep and allow time for processes to finish without constantly taxing CPU
    Start-Sleep -Seconds $seconds
}

function CompareFiles($ReferenceFilePath, $DifferenceFilePath, $OutFile)
{
    
    # Get Childitems and begin comparision
    $ReferenceFiles = Get-ChildItem $ReferenceFilePath -Recurse -File | Select-Object FullName,Name,LastWriteTime
    $DifferenceFiles = Get-ChildItem $DifferenceFilePath -Recurse -File | Select-Object FullName,Name,LastWriteTime
    $ComparisionResults = Compare-Object -ReferenceObject $ReferenceFiles -DifferenceObject $DifferenceFiles -Property Name,LastWriteTime -PassThru
    
    # This will only keep one line and write that object to the file.
    foreach ($comp in $ComparisionResults)
    {
        $compTemp = @()
        $compTemp = [pscustomobject] @{
            Path = $comp.FullName
            File = $comp.Name
            SideIndicator = $comp.SideIndicator
        }
        
        # Validate options and display or export where appropriate.
        if (!([string]::IsNullOrEmpty($OutFile)))
        {
            $compTemp | Export-Csv -Path $OutFile -NoTypeInformation -Append
        }
        
        if ($DisplayOutput.IsPresent)
        {
            Write-Host $compTemp
        }
    }
}
function StartMultiThread($ReferenceFilePaths, $DifferenceFilePaths, $OutFiles)
{
    foreach ($ReferenceFilePath in $ReferenceFilePaths)
    {
        # Only allow number of jobs/iterations going at once
        while ((Get-Job).count -ge $Iterations){CleanUpJobs}
        $DifferenceFilePath = $DifferenceFilePaths[$ReferenceFilePaths.indexof($ReferenceFilePath)]
        $OutFile = $OutFiles[$ReferenceFilePaths.indexof($ReferenceFilePath)]
        Start-Job -ScriptBlock ${Function:CompareFiles} -ArgumentList $ReferenceFilePath,$DifferenceFilePath,$OutFile
    }
    
    While ((Get-Job).count -gt 0){CleanUpJobs}
    return 0
}

function CleanUpJobs()
{
    $sleepSeconds = 5
    Start-Sleep -Seconds $sleepSeconds
    Remove-Job -State Completed
}


function TestFilePaths($RefDiffPaths, $headers)
{
    foreach ($path in ($RefDiffPaths.($headers[2])))
    {
        try 
        {
            $testPath = $path + "\.."
            Resolve-Path $testPath -ErrorAction Stop
        }
        catch 
        {
            DisplayErrorMessage 3 $path
        }
    }
    return $true
}

# Main
switch ($PSCmdlet.ParameterSetName)
{   
    "ComparePaths"
    {
        CompareFiles $ReferencePath $DifferencePath $OutFile
        $finished = 0
    }
    "CompareMultiPaths"
    {
        # Check for number of headers, should only be 2.
        $headers = ($RefDiffPaths[0].psobject.properties.name)
        if ((!(($headers.count) -eq 3) -and $MultipleOutFiles.IsPresent) -and !(($headers).count -eq 2)) {DisplayErrorMessage 1}
        if($MultipleOutFiles.IsPresent) {$pathsExist = TestFilePaths $RefDiffPaths $headers}
        
        # The number of reference and difference paths must match
        if (!(($RefCount = $RefDiffPaths.($headers[0]).count) -eq $RefDiffPaths.($headers[1]).count)) {DisplayErrorMessage 2}
        
        # Grab file paths to send to process
        $ReferenceFilePaths = $RefDiffPaths.$($headers[0])
        $DifferenceFilePaths = $RefDiffPaths.$($headers[1])
        if ($pathsExist -eq $true) {$OutFiles = $RefDiffPaths.$($headers[2])}
        $finished = StartMultiThread $ReferenceFilePaths $DifferenceFilePaths $OutFiles
    }
}

switch($finished)
    {
        0 {Write-Host **"Comparision Completed"** -ForegroundColor "Green"}
        1 {Write-Host "Unknown error, clear out jobs with get-job and remove-job functions" -ForegroundColor Red}
    }


# End Main
