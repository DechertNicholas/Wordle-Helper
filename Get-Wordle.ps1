<#
.SYNOPSIS
    Finds all possible wordle words for a given situation.
.DESCRIPTION
    Finds all possible wordle words for a given situation.
.PARAMETER Word
    Your current wordle setup. Enter missing letters as '_', and known letters as themselves 'a' (without quotes).
.PARAMETER YellowSetup
    Your current wordle setup. Enter non-yellow letters as '_', and yellow letters as themselves 'a' (without quotes).
.PARAMETER GreyLetters
    A comma separated list of letters that are grey.
.EXAMPLE
    Get-Wordle -Word _A_SE -YellowSetup __P__ -GreyLetters z,c,x
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
    $YellowSetup,
    [Parameter(Position = 2)]
    [char[]]
    $GreyLetters,
    [Parameter()]
    [switch]
    $Generate
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
        $extracted = $extracted | Sort-Object
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

# Make everything uppercase

$Word = $Word.ToUpper()

for ($i = 0; $i -lt $YellowSetup.Length; $i++) {
    $YellowSetup[$i] = [convert]::ToChar($YellowSetup[$i].ToString().ToUpper())
}
for ($i = 0; $i -lt $GreyLetters.Count; $i++) {
    $GreyLetters[$i] = [convert]::ToChar($GreyLetters[$i].ToString().ToUpper())
}

# Generate Alphabet
$Alphabet = [System.Collections.Generic.List[char]]::new()
for ([byte]$c = [char]'A'; $c -le [char]'Z'; $c++)
{
    $Alphabet.Add([char]$c)
}
Write-Verbose "Generated alphabet"

# Remove what isn't possible
foreach ($letter in $GreyLetters) {
    [void]$Alphabet.Remove([Convert]::ToChar($letter.ToString()))
}
Write-Verbose "Removed $($GreyLetters.Count) letters"

for ($i = 0; $i -lt $Word.Length; $i++ ) {
    if ($($Word[$i]) -ne "_") {
        $Unknowns--
    }
}

Write-Verbose "Solving for $Unknowns unknown positions"
if ($Generate) {
    $Possibilities = [Math]::Pow($Alphabet.Count,$Unknowns)
    Write-Verbose "There are $Possibilities possible combinations"

    for ($i = 0; $i -lt $Possibilities; $i++ ) {
        # The word being made
        $generated = ""
        $incremented = $false

        :word for ($j = 0; $j -lt $Word.Length; $j++ ) {
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
                    if ($Alphabet[$Counter[$j]] -eq $YellowSetup[$j]) {
                        # Whatever word is being generated will not be viable
                        $Counter[$Word.IndexOf("_")]++
                        $incremented = $true
                        break word
                    }
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

        if ($generated.Length -eq 5) {
            $percent = [math]::floor((($i+1)/$Possibilities)*100)
            # Make it look nicer
            if ($percent -eq 0) {$percent = 1}

            Write-Progress -Activity "Testing Generated Words" -Status "[$($i+1)/$Possibilities] Testing: $generated" -PercentComplete $percent
            # Handling for YelloLetters being null. Not clean, but easy
            if ($null -ne $YellowSetup) {
                $allPresent = $true
                foreach ($letter in $YellowSetup) {
                    # If one of the yellow letters is missing, don't print this word
                    if ($letter -ne "_" -and ($generated -notmatch $letter)) {
                        $allPresent = $false
                        break
                    }
                }
                if ($generated -in $AcceptedWords -and $allPresent) {
                    Write-Output $generated
                }
            } else {
                if ($generated -in $AcceptedWords) {
                    Write-Output $generated
                }
            }
        }
    }
} else {
    $Possibilities = $AcceptedWords.Count
    $attempt = 1
    Write-Verbose "There are $Possibilities possible combinations"
    foreach ($possible in $AcceptedWords) {
        $allPresent = $true
        $possible = $possible.ToUpper()
        $percent = [math]::floor(($attempt/$Possibilities)*100)
        # Make it look nicer
        if ($percent -eq 0) {$percent = 1}

        Write-Progress -Activity "Testing Words" -Status "[$attempt/$Possibilities] Testing: $possible" -PercentComplete $percent
        foreach ($letter in $GreyLetters) {
            if ($possible.Contains($letter)) {
                $allPresent = $false
                break
            }
        }
        # Handling for YelloLetters being null. Not clean, but easy
        if ($null -ne $YellowSetup) {
            foreach ($letter in $YellowSetup) {
                $index = $YellowSetup.IndexOf($letter)
                # If one of the yellow letters is missing, don't print this word
                if ($letter -ne "_" -and ($possible -notmatch $letter) -or $possible[$index] -eq $letter) {
                    $allPresent = $false
                    break
                }
            }
        }
        foreach ($letter in $Word.ToCharArray()) {
            if ($letter -ne "_") {
                $index = $Word.IndexOf($letter)
                if ($possible[$index] -ne $letter) {
                    $allPresent = $false
                    break
                }
            }
            
        }
        if ($allPresent) {
            Write-Output $possible
        }
        $attempt++
    }
}