Function Get-ADMembership {
  <#
  .SYNOPSIS
    To use for working out which groups an AD member (user or group) is a member of.

  .DESCRIPTION
    Returns a custom PS object containing a list of groups that an AD member is a
    member of and any groups those groups may be a member of (if -Recursive switch used)
  
  .PARAMETER Identity
    [string](Mandatory)
    Name of the AD member to get the membership for (i.e. the AD groups that this
    AD member is a member of)
  
  .PARAMETER Server
    [string](Mandatory)
    Name of domains searching through; domain1.co.nz domain2.co.nz domain3.co.nz etc
  
  .PARAMETER Recursive
    [switch]
    if this switch exists, then any nested memberof groups that may exist are also checked for any memberofs
  
  .PARAMETER RecursionMaxCount
    [int]
    Maximum number of memberof groups to recursively check. if this doesn't exist then will continue
    until no further nested groups are found (or session memory is exhausted)

  .PARAMETER IncludeFSP
    [switch]
    if this switch exists, then any identities and nested memberof groups are also checked across the other domains
    (if multiple domains are passed in via the -Server parameter) to see if they may be members of groups in
    these other domains as foreignSecurityPrincipals (FSP)

  .EXAMPLE
    Get-ADMembership -Identity 'allan' -Server domain1.co.nz,domain2.co.nz -Recursive -IncludeFSP -Verbose | Where-Object {$_.NestingLevel -ge 0} | Select-Object Identity,Domain,MemberOf,MemberOfDomain,NestingLevel | Sort-Object MemberOf | Format-Table -AutoSize

  .EXAMPLE
    $o = Get-ADMembership -Identity 'video editor' -Server domain1.co.nz,domain2.co.nz -Verbose -Recursive -IncludeFSP
    $o | Where-Object {$_.NestingLevel -ge 0} | Select-Object Identity,Domain,MemberOf,MemberOfDomain,NestingLevel | Sort-Object Identity | Format-Table -AutoSize

  .EXAMPLE
    $o = Get-ADMembership -Identity 'stephen' -Server domain1.co.nz,domain2.co.nz -Verbose -Recursive -IncludeFSP
    $o | Where-Object {$_.NestingLevel -ge 0} | Select-Object Identity,Domain,MemberOf,MemberOfDomain,@{name='FSP';expression={if($_.Domain -ne $_.MemberOfDomain){$true}else{$false}}} | Sort-Object Identity | Format-Table -AutoSize

  .EXAMPLE
    Get-ADMembership -Identity 'stephen' -Server domain1.co.nz,domain2.co.nz -Verbose -Recursive -IncludeFSP |
      Where-Object {$_.NestingLevel -ge 0} |
      Select-Object Identity,Domain,MemberOf,MemberOfDomain,@{name='FSP';expression={if($_.Domain -ne $_.MemberOfDomain){$true}else{$false}}} |
      Sort-Object Identity |
      Format-Table -AutoSize

  .EXAMPLE
    Get-ADMembership -Identity 'APP-SGTest1' -Server 'domain1.co.nz' | ft -AutoSize

  .EXAMPLE
    Get-ADMembership -Identity 'stephen' -Server 'domain2.co.nz' | ft

  .EXAMPLE
    Get-ADMembership -Identity 'stephen' -Server 'domain1.co.nz' -Recursive | Select Identity,Domain,MemberOf,MemberOfDomain,MemberOfSID,NestingLevel

  .EXAMPLE
    Get-ADMembership -verbose -Identity $Identity -Server 'domain3.co.nz' -Recursive | Select Identity,Domain,MemberOf,MemberOfDomain,MemberOfSID,NestingLevel
  
  .OUTPUT
    Custom PS Object with the following parameters:
      "Identity" = the ad member being checked to see which ad groups it is a member of
      "Domain" = the domain that this 'Identity' ad member was found in
      "MemberOf" = the ad group that the 'Identity' ad member is a member of
      "MemberOfDomain" = the domain that this 'MemberOf' ad member was found in
      "MemberOfSID" = the objectSID for this 'MemberOf' ad member
      "NestingLevel" = -1,0,1,2,3,4,5,6... (-1 = the original Identity being checked, 0 = directly a MemberOf, 1 = nested, 2 = nested another level...)

  .NOTES

  .HISTORY
    v1.0 - Created March 2020
    v1.1 - Added FSP lookup into this function rather than via another script. Required creating dynamic variables
    v1.2 - Turned the FSP lookup and additions to the returned obect, into functions Get-FSPMembers and Add-ObjectInfo
    v1.3 - Fixed a bug in the FSP function Add-ObjectInfo which would blaff if there was no objectSid returned for the -MemberOfSID parameter
           Found $obj.ObjectSid might need to be $obj.ObjectSid.Value
    v1.4 - Added a catch for any null Get-ADObjects for the MemberOf lookups
    v1.5 - Some Get-ADObjects return multiple names for a user?! Have added -> ($xxx.Name | Sort -Unique) to deal with any of those that are found
    v1.6 - Added ObjectClass and MemberOfObjectClass properties to returned object
           Filtering Get-ADObjects for only "user" and "group" .ObjectClass values (so we don't get any doubled up results when there may also be
           a matching "contact" ObjectClass

  .AUTHOR
        Name: Steve Geall
        Date: March 2020
    Version: 1.6
    Updated: 7 Mar 2020
  #>
  [CmdletBinding()]
  param(
      [Parameter(
          Mandatory = $true,
          ValueFromPipeline = $true,
          ValueFromPipelineByPropertyName = $true,
          Position = 0
      )]
      [string[]]
      $Identity,
      [Parameter(
          Mandatory = $true,
          ValueFromPipeline = $true,
          ValueFromPipelineByPropertyName = $true,
          Position = 1
      )]
      [string[]]
      $Server,
      [switch]
      $Recursive,
      [int]
      $RecursionCount = 0,
      [int]
      $RecursionMaxCount,
      [switch]
      $IncludeFSP
  )

  begin {
    foreach ($domain in $Server) {
      try {
        Get-ADDomain $domain | Out-Null
      } catch {
        Throw "This -Server parameter passed in [$domain] is invalid. Exiting..."
      }
    }
    if ($IncludeFSP) {
      write-verbose "-IncludeFSP paramter passed in, so create dynamic {domainname}_allADGroups variables"
      foreach ($domain in $Server) {
          New-Variable -Name "$($domain)_allADGroups" -Value (Get-ADGroup -Properties Name,Members -Filter * -Server $domain) -Force
      }
    }
    # if we've called this function recursively then no need to initialise this variable
    if ($RecursionCount -lt 1) {
      $script:objToReturn = @()
    }
    
  }

  process {
    function Add-ObjectInfo {
      param (
        [Parameter(Mandatory = $true)]
        [string]$Identity,
        [Parameter(Mandatory = $true)]
        [string]$MemberOf,
        [Parameter(Mandatory = $true)]
        [string]$ObjectClass,
        [Parameter(Mandatory = $true)]
        [string]$MemberOfObjectClass,
        [Parameter(Mandatory = $true)]
        [string]$Domain,
        [Parameter(Mandatory = $true)]
        [string]$MemberOfDomain,
        [Parameter(Mandatory = $true)]
        [string]$MemberOfSID,
        [Parameter(Mandatory = $true)]
        [int]$NestingLevel
      )
      $info = @{
        "Identity" = $Identity
        "MemberOf" = $MemberOf
        "ObjectClass" = $ObjectClass
        "MemberOfObjectClass" = $MemberOfObjectClass
        "Domain" = $Domain
        "MemberOfDomain" = $MemberOfDomain
        "MemberOfSID" = $MemberOfSID
        "NestingLevel" = $NestingLevel
      }
      $tempObj = New-Object -TypeName PSObject -Property $info
      $script:objToReturn += $tempObj
      Write-Verbose "### Added an item to the object that will be returned ###"
    } # end Add-ObjectInfo function
    function Get-FSPMembers {
      param (
        $domain,
        $tempADObj
      )
      # search any other domains that may have been passed in, but no need to search the same domain we are currently in because can't have an FSP in the same domain
      Write-Verbose "      -IncludeFSP parameter passed in, so do an FSP check, across any domains passed in via the -Server parameter, other than the domain this group is in [$domain]"
      foreach ($fspDomain in $Server) {
        if ($fspDomain -ne $domain) {
          Write-Verbose "        checking if this group is nested as an FSP over at domain [$fspDomain] (main domain is [$domain])..."
          # get domain DN for programatical use in the -contains lookup below with the match = CN=$($tempADObj.objectSid),CN=ForeignSecurityPrincipals,$domainDN"
          $domainDN = (Get-ADDomain $fspDomain).DistinguishedName 
          # get matching dynamically created variable for this fspDomain that was created at the beginning of this function
          $allADGroupsInThisDomain = (Get-Variable -Name "$fspDomain`_allADGroups").Value
          $fspFindCount=0
          write-verbose "          if (`$adGroup.members -contains ""CN=$($tempADObj.objectSid),CN=ForeignSecurityPrincipals,$domainDN"") <- that sid is for the ad group name ($($tempADobj.Name))"
          foreach ($adGroup In $allADGroupsInThisDomain) {
            if ($adGroup.Members -contains "CN=$($tempADObj.objectSid),CN=ForeignSecurityPrincipals,$domainDN") {
              write-verbose "          found a nested group via FSP ($($tempADObj.Name)[$domain] is an FSP member in the group $($adGroup.Name)[$fspDomain])"
              $fspFindCount++
              $adGroupAsADObject = Get-ADObject -Filter 'Name -eq $adGroup.Name' -Server $fspDomain -Properties * | Where-Object {$_.ObjectClass -eq "user" -Or $_.ObjectClass -eq "group"}
              if([string]::IsNullOrEmpty($adGroupAsADObject.objectSid)){$memberOfSID = "no sid returned from Get-ADObject"}else{$memberOfSID=$adGroupAsADObject.objectSid.Value}
              #write-host "adding object info initially -Identity $($tempADObj.Name) -MemberOf $($adGroup.Name) -Domain $domain -MemberOfDomain $fspDomain -NestingLevel 0" -f Cyan
              Add-ObjectInfo -Identity ($tempADObj.Name | Sort -Unique) -MemberOf ($adGroup.Name | Sort -Unique) -Domain $domain -MemberOfDomain $fspDomain -MemberOfSID $memberOfSID -ObjectClass $tempADObj.ObjectClass -MemberOfObjectClass $adGroupAsADObject.ObjectClass -NestingLevel 0
            }
          }
          write-verbose "        done (found nested FSP groups = $fspFindCount)."
        }
      }
    } # end Get-FSPMembers function

    Write-Verbose "Start function Get-ADMembership"
    if([string]::IsNullOrEmpty($RecursionCount)){$RecursionCount=0}
    if([string]::IsNullOrEmpty($RecursionMaxCount)){$RecursionMaxCount=0}
    Write-Verbose "RecursionCount=$RecursionCount"
    Write-Verbose "RecursionMaxCount=$RecursionMaxCount"
    foreach ($domain in $Server) {
      foreach ($Id in $Identity) {
        Write-Verbose "Processing identity: $Id$(if($domain){"[$domain]"})"
        $adObj = $null
        $adObj = Get-ADObject -Filter 'Name -eq $Id -Or userPrincipalName -eq $Id -Or SamAccountName -eq $Id -Or DisplayName -eq $Id' -Server $domain -Properties * | Where-Object {$_.ObjectClass -eq "user" -Or $_.ObjectClass -eq "group"}
        if (-Not($adObj)) {
          Write-Verbose "  No ADObject found for ($Id) in [$domain], no need to attempt to get membership of non-existant object"
          Continue
        }
        Write-Verbose "  Valid AD Object found for ($Id) in [$domain]`: $adObj"
        Write-Verbose "  Valid AD Object `$adObj.name`: $($adObj.Name | Sort -Unique)"
        Write-Verbose "  Valid AD Object `$adObj.objectClass`: $($adObj.ObjectClass)"
        Write-Verbose "  There are $(($adObj.MemberOf).Count) groups that $($adObj.Name | Sort -Unique) is a member of$(if(($adObj.MemberOf).Count -gt 0){", they are: $($adObj.MemberOf)"})"
        # this is the root member so add this item to the object that will be returned before beginning to loop over any group membership
        # set nesting level to -1 so that can be used in final output to filter it out if not required (usually); we need this entry so
        # it can be referenced later if we want to look over other domains to see if it has been nested across trusted domains as a foreignSecurityPrincipal
        #write-host "adding object info initially -Identity $($adObj.Name | Sort -Unique) -MemberOf $($adObj.Name | Sort -Unique) -Domain $domain -MemberOfDomain $domain -NestingLevel -1" -f Cyan
        Add-ObjectInfo -Identity ($adObj.Name | Sort -Unique) -MemberOf ($adObj.Name | Sort -Unique) -Domain $domain -MemberOfDomain $domain -MemberOfSID $adObj.objectSid.Value -ObjectClass $adObj.ObjectClass -MemberOfObjectClass $adObj.ObjectClass -NestingLevel -1
        if ($IncludeFSP) {
          Get-FSPMembers -domain $domain -tempADObj $adObj
        }
        foreach ($member in $adObj.MemberOf) {
          Write-Verbose "  Attempt to get the ADObject (ALL properties) for this member: $member, in [$domain] to see if it is also a member of further ad groups"
          $tempADobj = $null
          try {
              $tempADobj = Get-ADObject $member -Server $domain -Properties * | Where-Object {$_.ObjectClass -eq "user" -Or $_.ObjectClass -eq "group"}
          } catch {
              Write-Verbose "    in catch after: Get-ADObject $member -Server $domain -Properties * | Where-Object {`$_.ObjectClass -eq ""user"" -Or `$_.ObjectClass -eq ""group""}"
              Write-Verbose "    $($PSItem.Exception.Message)"
              Write-Verbose "    No ADObject found for ($member) in [$domain], no need to attempt to get membership of non-existant object"
              Continue
          }
          Write-Verbose "  Valid AD Object found for ($member) in [$domain]`: $tempADobj"
          Write-Verbose "  There are $(($tempADobj.MemberOf).Count) groups that $($tempADobj.Name) is a member of $(   if(($tempADobj.MemberOf).Count -gt 0){", they are: $($tempADobj.MemberOf)"})"
          Write-Verbose "    ObjectClass is: $($tempADobj.ObjectClass) - will always be a group (and never returns FSP via memberof!) as can only be a ""memberOf"" a group"
          Write-Verbose "    `$tempADobj.MemberOf: $($tempADobj.MemberOf)"
          Write-Verbose "    `$tempADobj.Name: $($tempADobj.Name)"   
          Write-Verbose "    `$adObj.Name: $($adObj.Name | Sort -Unique)"          
          #write-host "adding object info in memberOf loop -Identity $($adObj.Name | Sort -Unique) -MemberOf $($tempADobj.Name) -Domain $domain -MemberOfDomain $domain -NestingLevel $RecursionCount" -f Magenta
          Add-ObjectInfo -Identity ($adObj.Name | Sort -Unique) -MemberOf $tempADobj.Name -Domain $domain -MemberOfDomain $domain -MemberOfSID $tempADobj.objectSid -ObjectClass $adObj.ObjectClass -MemberOfObjectClass $tempADobj.ObjectClass -NestingLevel $RecursionCount
          if ($Recursive -And -Not($tempADobj.ObjectClass -eq "user") -And @($tempADobj.MemberOf).Count -gt 0) {
            if ($tempADobj.ObjectClass -eq "group") {
              if ($RecursionMaxCount -eq 0 -Or $RecursionCount -eq 0 -Or ($RecursionCount -lt $RecursionMaxCount)) {
                Write-Verbose "    This member (Name: $($tempADobj.Name) / SamAccountName: $($tempADobj.SamAccountName)[$(if($tempADobj.FSPDomain){$tempADobj.FSPDomain}else{$domain})]) is a nested AD Group inside the parent AD Group (Name: $($adObj.Name | Sort -Unique)[$domain]) AND the -Recursive switch has been passed in to this function so recursively look inside the AD Group (Name: $($tempADobj.Name) / SamAccountName: $($tempADobj.SamAccountName)[$(if($tempADobj.FSPDomain){$tempADobj.FSPDomain}else{$domain})]) for any further members..."
                # TO DO: add a check here to see if we've already passed this group and server through "Get-ADMembership" to save us hitting a loop in the group memberships (e.g. A->B->C->A)
                try {
                  $tempParams = @{
                    Verbose = if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){$true}else{$false}
                    Identity = $tempADobj.SamAccountName
                    Server = $domain
                    Recursive = $true
                    RecursionCount = $RecursionCount+1
                    RecursionMaxCount = $RecursionMaxCount
                  }
                  #write-host "RECURSION START" -f Red
                  Get-ADMembership @tempParams
                  Write-Verbose "    -return from recursion-"
                } catch {
                  Write-Verbose "      in catch after recursive: Get-ADMembership $tempParams"
                  Write-Verbose "      $($PSItem.Exception.Message)"
                }
              }
            }
          }
          if ($IncludeFSP) {
            Get-FSPMembers -domain $domain -tempADObj $tempADobj
          }
          Write-Verbose "  End Attempt to get the ADObject"
        } # end looping each memberof
      } # end looping each identity
    } # end looping each domain
    Write-Verbose "End function Get-ADMembership"
    if ($RecursionCount -lt 1) {
      Return $script:objToReturn
    }
  }
} # end Get-ADMembership function