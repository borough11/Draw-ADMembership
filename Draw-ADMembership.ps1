<#
  .SYNOPSIS
    Draws a diagram showing all the groups that the user/group passed into this script is a member of. Including any AD Groups that
    have been nested cross-domains as foreignSecurityPrincipals (FSP).

  .DESCRIPTION
    Create an HTML page with a graphical representation of all the groups that the user/group passed into this script via the -LookupMember
    parameter is a member of, and included in the HTML page - the results table generated from the dot sourced Get-ADMembership function.
  
  .PARAMETER LookupMember
    [string](Mandatory)
    Name of the user or ad group to list all the groups they may be a member of
    Accepts Name, userPrincipalName, SamAccountName or DisplayName
  
  .PARAMETER Domains
    [string](Mandatory)
    Names of all the domains to search through, i.e. domain1.co.nz,domain2.co.nz,domain3.co.nz OR domain1.co.nz,domain3.co.nz etc

    *** NOTE
      At the section below that sets the colours for the output based on each domain, you'll have to adjust the names of the
      domain the Switch command to suit your domains...
        # set colours for the domains, for both members and memberOfs
            switch ($n.Domain) {
    ***              

  .EXAMPLE
    Draw-Get-ADMembership -LookupMember 'stephen'

  .EXAMPLE
    Draw-Get-ADMembership -LookupMember 'allan' -Domains 'domain1.co.nz,domain2.co.nz,domain3.co.nz'
  
  .OUTPUT
    HTML file in the root directory that this script is running from

  .NOTES
    requires...
    * note these are automatically installed and dot-sourced when the script runs. Please put Get-ADMembership.ps1 in the same root folder as this script
    - module PSWriteHTML (available from the Microsoft repo "Install-Module PSWriteHTML -Force" (author: https://evotec.xyz/))
    - function Get-ADMembership
    * note these are automatically installed and dot-sourced when the script runs. Please put Get-ADMembership.ps1 in the same root folder as this script


    # NewDiagramNode parameters
    # -ColorHighlightBackground
    # -ColorHighlightBorder
    # -ColorHoverBackground
    # -ColorHoverBorder
    # -FontAlign
    # -FontBackground
    # -FontColor
    # -FontName
    # -FontSize
    # -FontVAdjust
    # -WidthConstraint
    # -Size
    # -Shape circle, dot, diamond, ellipse, database, box, square, triangle, triangleDown, text, star, hexagon
    # fontawesome icons
    # None, Black, Navy, DarkBlue, MediumBlue, Blue, DarkGreen, Green, Teal, DarkCyan, DeepSkyBlue, DarkTurquoise, MediumSpringGreen, Lime, SpringGreen, Aqua, Cyan, MidnightBlue, DodgerBlue, LightSeaGreen, ForestGreen, SeaGreen, DarkSlateGray, DarkSlateGrey, LimeGreen, MediumSeaGreen, Turquoise, RoyalBlue, SteelBlue, DarkSlateBlue, MediumTurquoise, Indigo, DarkOliveGreen, CadetBlue, CornflowerBlue, MediumAquamarine, DimGray, DimGrey, SlateBlue, OliveDrab, SlateGray, SlateGrey, LightSlateGray, LightSlateGrey, MediumSlateBlue, LawnGreen, Chartreuse, Aquamarine, Maroon, Purple, Olive, Grey, Gray, SkyBlue, LightSkyBlue, BlueViolet, DarkRed, DarkMagenta, SaddleBrown, DarkSeaGreen, LightGreen, MediumPurple, DarkViolet, PaleGreen, DarkOrchid, YellowGreen, Sienna, Brown, DarkGray, DarkGrey, LightBlue, GreenYellow, PaleTurquoise, LightSteelBlue, PowderBlue, FireBrick, DarkGoldenrod, MediumOrchid, RosyBrown, DarkKhaki, Silver, MediumVioletRed, IndianRed, Peru, Chocolate, Tan, LightGray, LightGrey, Thistle, Orchid, Goldenrod, PaleVioletRed, Crimson, Gainsboro, Plum, BurlyWood, LightCyan, Lavender, DarkSalmon, Violet, PaleGoldenrod, LightCoral, Khaki, AliceBlue, Honeydew, Azure, SandyBrown, Wheat, Beige, WhiteSmoke, MintCream, GhostWhite, Salmon, AntiqueWhite, Linen, LightGoldenrodYellow, OldLace, Red, Fuchsia, Magenta, DeepPink, OrangeRed, Tomato, HotPink, Coral, DarkOrange, LightSalmon, Orange, LightPink, Pink, Gold, PeachPuff, NavajoWhite, Moccasin, Bisque, MistyRose, BlanchedAlmond, PapayaWhip, LavenderBlush, Seashell, Cornsilk, LemonChiffon, FloralWhite, Snow, Yellow, LightYellow, Ivory, White


  .HISTORY
    v1.0 - Created March 2020
    v1.1 - Use Get-InstalledModule instead of Get-Module to check if PSWriteHTML module installed

  .AUTHOR
        Name: Steve Geall
        Date: March 2020
     Version: 1.1
     Updated: 9 Mar 2020
#>
param (
    # Name, userPrincipalName, SamAccountName, DisplayName
    [Parameter(
          Mandatory = $true,
          ValueFromPipeline = $true,
          ValueFromPipelineByPropertyName = $true,
          Position = 0
    )]
    [string]
    $LookupMember,

    # comma separated list of domains like domain1.co.nz,domain2.co.nz,domain3.co.nz
    [Parameter(
          Mandatory = $false,
          ValueFromPipeline = $true,
          ValueFromPipelineByPropertyName = $true,
          Position = 1
    )]
    [string[]]
    $Domains # set as $Domains = @('domain1.co.nz','domain2.co.nz','domain3.co.nz') for a default list
)

Write-Host "`r`nBegin Draw-AdMembership for member: ($LookupMember) across domains: [$Domains]..."
# requirements
Write-Host "Gathering requirements..."
If(-Not(Get-InstalledModule -Name PSWriteHTML)) {
    Install-Module PSWriteHTML -Force
}
If(Get-Item Function:\Get-ADMembership -ErrorAction SilentlyContinue) {
    Remove-Item Function:\Get-ADMembership
} 
. .\Get-ADMembership.ps1

Write-Host "Building AD Membership (can take a while if the member is a member of many groups)..."

try {
  $results = Get-ADMembership -Identity $LookupMember -Server $Domains -Recursive -IncludeFSP | Where-Object {$_.NestingLevel -ge 0} | Select-Object Identity,Domain,MemberOf,MemberOfDomain,ObjectClass,MemberOfObjectClass -Unique

  Write-Host "Creating HTML page...($PSScriptRoot\$LookupMember-Membership.html)"
  New-HTML -TitleText "$LookupMember is a memberOf..." -UseCssLinks:$true -UseJavaScriptLinks:$true -FilePath $PSScriptRoot\ADMembership-$LookupMember-$(Get-Date -F "yyyy-MM-dd").html {
    
    New-HTMLSection -HeaderText "$LookupMember is a memberOf..." -CanCollapse {
      New-HTMLPanel {
        New-HTMLDiagram -Height '1500px' {
          New-DiagramOptionsPhysics -Enabled $true -StabilizationEnabled $false  -AdaptiveTimestep $false
          New-DiagramOptionsInteraction -Hover $false -NavigationButtons $true -HoverConnectedEdges $true
          
          foreach($n in $results) {
            # set colours for the domains, for both members and memberOfs
            switch ($n.Domain) {
                "domain2.co.nz" {
                  $domainNodeColour = "LightPink"
                  $domainNodeHighlight = "HotPink"
                }
                "domain1.co.nz" {
                  $domainNodeColour = "LightBlue"
                  $domainNodeHighlight = "Teal"
                }
                "domain3.co.nz" {
                  $domainNodeColour = "PaleGoldenrod"
                  $domainNodeHighlight = "Goldenrod"
                }
            }
            switch ($n.MemberOfDomain) {
              "domain2.co.nz" {
                $memberOfNodeColour = "LightPink"
                $memberOfNodeHighlight = "HotPink"
              }
              "domain1.co.nz" {
                $memberOfNodeColour = "LightBlue"
                $memberOfNodeHighlight = "Teal"
              }
              "domain3.co.nz" {
                $memberOfNodeColour = "PaleGoldenrod"
                $memberOfNodeHighlight = "Goldenrod"
              }
          }

          # set icon and node shape based on objectclass
          if($n.ObjectClass -eq "user") {
            $ico = "user"
            $shp = "ellipse"
          } else {
            $ico = "folder"
            $shp = "box"
          }

          ###
          # create member/identity level nodes
          ###
            # if there is a member match to the lookupmember then this a root level, create node as icon with larger text
            if($n.Identity -replace '\.', ' ' -eq $LookupMember -Or $n.Identity -replace ' ', '.' -eq $LookupMember) {
              $HashArguments = @{
                Label = "$($n.Identity) [$($n.Domain)]"
                FontSize = '20'
                IconSolid =  $ico
                IconColor = $domainNodeHighlight
              }
              New-DiagramNode @HashArguments
            } else {
              # not a root level lookupmemeber match, just create the member node
              $HashArguments = @{
                Label = "$($n.Identity) [$($n.Domain)]"
                ColorBackground = $domainNodeColour
                ColorHighlightBackground = $domainNodeHighlight
                Shape = $shp
              }
              New-DiagramNode @HashArguments
            }

          ###
          # create memberOf level nodes
          ###
            if ($n.Domain -ne $n.MemberOfDomain) {
              $colBG = $memberOfNodeColour
              $colHL = $memberOfNodeHighlight
            } else {
              #New-DiagramNode -Label "$($n.MemberOf)-$($n.MemberOfDomain)" -ColorBackground $domainNodeColour
              $colBG = $domainNodeColour
              $colHL = $domainNodeHighlight
            }
            if ($n.MemberOfObjectClass -eq "user") {
              $shp = "ellipse"
            } else {
              $shp = "box"
            }
            $HashArguments = @{
              Label = "$($n.MemberOf) [$($n.MemberOfDomain)]"
              ColorBackground = $colBG
              ColorHighlightBackground = $colHL
              Shape = $shp
            }
            New-DiagramNode @HashArguments

          ###
          # create the links between the nodes
          ###
            if ($n.Domain -ne $n.MemberOfDomain) {
              # node domains don't match so this must be an FSP
              $HashArguments = @{
                From = "$($n.Identity) [$($n.Domain)]"
                To = "$($n.MemberOf) [$($n.MemberOfDomain)]"
                ArrowsToEnabled = $true
                ArrowsMiddleEnabled = $false
                ArrowsFromEnabled = $false
                Color = "Red"
                Dashes = $true
                Label = "FSP"
              }
              New-DiagramLink @HashArguments
              #New-DiagramLink -From "$($n.Identity) [$($n.Domain)]" -To "$($n.MemberOf) [$($n.MemberOfDomain)]" -ArrowsToEnabled $true -ArrowsMiddleEnabled $false -ArrowsFromEnabled $false -Color Red -Dashes $true -Label "FSP"
            } else {
              # matching domains, so just a normal link
              $HashArguments = @{
                From = "$($n.Identity) [$($n.Domain)]"
                To = "$($n.MemberOf) [$($n.MemberOfDomain)]"
                ArrowsToEnabled = $true
                ArrowsMiddleEnabled = $false
                ArrowsFromEnabled = $false
                Color = "BlueViolet"
                Dashes = $false
                Label = ""
              }
              New-DiagramLink @HashArguments
              #New-DiagramLink -From "$($n.Identity) [$($n.Domain)]" -To "$($n.MemberOf) [$($n.MemberOfDomain)]" -ArrowsToEnabled $true -ArrowsMiddleEnabled $false -ArrowsFromEnabled $false -Color BlueViolet -Dashes $false -Label ""
            }
          }
        }
      }
    } # end html section

    New-HTMLSection -HeaderText "$LookupMember is a memberOf..." -CanCollapse {
      New-HTMLPanel {
        New-HTMLTable -DataTable $results
      }
    } # end html section

  } -ShowHTML
} catch {
  Write-Host "$($PSItem.Exception.Message)" -f Red
}
Write-Host "Complete.`r`n"