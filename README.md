# Draw-ADMembership.ps1 & Draw-ADGroupMember2.ps1
   
I was excited about Get-ADMembership & Get-ADGroupMember2 to allow us to see nested groups including nested groups across domains. Now off the back of those functions and with EvoTek's PSWriteHTML https://evotec.xyz/easy-way-to-create-diagrams-using-powershell-and-pswritehtml/, we have 2 new scripts available Draw-ADMembership.ps1 & Draw-ADGroupMember2.ps1

## Draw-ADMembership.ps1

This script will import the required modules and function and then output an HTML file containing a diagram and datagrid of the membership that the -LookupMember belongs to within and across the -Domains passed into the script.

### How can I use this?!
	
1. Create a new folder wherever you keep your PowerShell scripts - "Draw-ADMembership"
2. Copy the 2 files "Get-ADMembership.ps1" and "Draw-ADMembership.ps1" into that folder
3. Start a PowerShell session, CD to your PowerShell scripts folder\Draw-ADMembership\
4. Run Draw-ADMembership.ps1 -LookupMember "person.name" Or Draw-ADMembership.ps1 -LookupMember "ad group name"


## Draw-ADGroupMember2.ps1

***not uploaded yet***

~~This script will import the required modules and function and then output an HTML file containing a diagram and datagrid of the groups that are members of the -LookupMember, starting at the -Domain passed into to the script.~~

### How can I use this?!
	
~~1. Create a new folder wherever you keep your PowerShell scripts - "Draw-ADGroupMember2"~~
~~2. Copy the 2 files attached to this post "Get-ADGroupMember2.ps1" and "Draw-ADGroupMember2.ps1" into that folder~~
~~3. Start a PowerShell session, CD to your PowerShell scripts folder\Draw-ADGroupMember2\~~
~~4. Run Draw-ADGroupMember2.ps1 -LookupMember "ad group name" -Domain domainname.co.nz~~
***not uploaded yet***

## And what do I get?

These amazing visual diagrams like people's/group's membership...

![Draw-ADMembership](https://github.com/borough11/Draw-ADMembership/blob/master/Draw%20AD%20Membership.png?raw=true "Draw-ADMembership")

Along with a searchable, sortable, reorderable, exportable view of the entire result object (basically what the PowerShell Get-*** functions output)...

![Draw-ADMembership table](https://github.com/borough11/Draw-ADMembership/blob/master/Draw%20AD%20Membership%20-%20table.png?raw=true "Draw-ADMembership")
