<#
.SYNOPSIS
    Finds all possible wordle words for a given situation.
.DESCRIPTION
    Finds all possible wordle words for a given situation.
.PARAMETER Word
    Your current wordle setup. Enter missing characters as '_', and known letters as themselves 'a' (without quotes).
.PARAMETER YellowLetters
    A comma separated list of letters that are yellow.
.PARAMETER GreyLetters
    A comma separated list of letters that are grey.
.EXAMPLE
    Get-Wordle -Word _A_SE -YellowLetters p -GreyLetters z,c,x
    Word is known to have A in the 3rd position, and S and E in the 4th and 5th position. P is known to be somewhere, and z, c, and x are not
    in the word at all.
.NOTES
    Generates AcceptedWords.txt next to the script. This is downloaded from Wordle's website
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]
    $Word = "_____",
    [Parameter(Position = 1)]
    [char[]]
    $YellowLetters,
    [Parameter(Position = 2)]
    [char[]]
    $GreyLetters
)

function GetWordList {
    <#
    .SYNOPSIS
        Gets the word list from wordle and saves it locally
    #>
    $res = Invoke-WebRequest -Uri "https://www.nytimes.com/games/wordle/main.b2a7bd18.js"
    if ($res.Content -match 'Ma=\[.*?\]') {
        $extracted = $matches[0]
        $extracted = $extracted -replace '"' # Clear all #
        $extracted = $extracted -replace 'Ma=\['
        $extracted = $extracted -replace ']'
        $extracted = $extracted.split(',')
        $extracted | Out-File "$(Split-Path $PSCommandPath -Parent)\AcceptedWords.txt"
    }
}

# How many positions we don't know. Default all 5
$Unknowns = 5
# Stores iteration count
$Counter = @(0,0,0,0,0)
# So we don't have to calculate again
$Possibilities = 0
if(-not (Test-Path "$(Split-Path $PSCommandPath -Parent)\AcceptedWords.txt")) {
    GetWordList
}
$AcceptedWords = Get-Content "$(Split-Path $PSCommandPath -Parent)\AcceptedWords.txt"

# Generate Alphabet
$Alphabet = [System.Collections.Generic.List[char]]::new()
for ([byte]$c = [char]'A'; $c -le [char]'Z'; $c++)
{
    $Alphabet.Add([char]$c)
}
Write-Verbose "Generated alphabet"

# Remove what isn't possible
foreach ($letter in $GreyLetters) {
    [void]$Alphabet.Remove([Convert]::ToChar($letter.ToString().ToUpper()))
}
Write-Verbose "Removed $($GreyLetters.Count) letters"

for ($i = 0; $i -lt $Word.Length; $i++ ) {
    if ($($Word[$i]) -ne "_") {
        $Unknowns--
    }
}

$Possibilities = [Math]::Pow($Alphabet.Count,$Unknowns)
Write-Verbose "Solving for $Unknowns unknown positions"
Write-Verbose "There are $Possibilities possible combinations"

for ($i = 0; $i -lt $Possibilities; $i++ ) {
    # The word being made
    $generated = ""
    $incremented = $false

    for ($j = 0; $j -lt $Word.Length; $j++ ) {
        if ($($Word[$j]) -eq "_") {
            # If this counter is at the end of the alphabet
            if ($Counter[$j] -eq ($Alphabet.Count)) {
                $Counter[$j] = 0
                for ($k = $j + 1; $k -lt 5; $k++) {
                    if ($($Word[$k]) -eq "_") {
                        $Counter[$k]++
                        break
                    }
                }
                $generated += $Alphabet[$Counter[$j]]
            } else {
                $generated += $Alphabet[$Counter[$j]]
                if ($incremented -eq $false) {
                    $Counter[$Word.IndexOf("_")]++
                    $incremented = $true
                }
            }
        } else {
            $generated += $Word[$j]
        }
    }

    Write-Progress -Activity "Testing Generated Words" -Status "[$i/$Possibilities] Testing: $generated" -PercentComplete (($i/$Possibilities)*100)
    # Handling for YelloLetters being null. Not clean, but easy
    if ($null -ne $YellowLetters) {
        if ($generated -in $AcceptedWords -and $null -ne ($YellowLetters | Where-Object { $generated -match $_ })) {
            Write-Output $generated
        }
    } else {
        if ($generated -in $AcceptedWords) {
            Write-Output $generated
        }
    }
    
}