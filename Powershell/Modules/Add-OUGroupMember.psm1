﻿<#
.Synopsis
   Add users to Groups based on OU.
.DESCRIPTION
   Add users to specified group based on OU membership.
.EXAMPLE
   Add-OUGroupMember -ShadowGroup "CN=all,OU=Mail Enabled Groups,DC=contoso,DC=com" -OU "OU=Users,DC=contoso,DC=com"
.EXAMPLE
   Add-OUGroupMember -ShadowGroup "CN=LA-Office,OU=Mail Enabled Groups,DC=contoso,DC=com" -OU "OU=LA,OU=Users,DC=contoso,DC=com" -OU2 "OU=Upper Management,OU=Users,DC=contoso,DC=com" -SharedGroupFilter LA
#>
function Add-OUGroupMember
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Parameter containing the DN of the group to add users to.
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $ShadowGroup,

        # Parameter containing the DN of the OU to add users from.
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        $OU,

        # Parameter containing the DN of the second OU to add users from if applicable.
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $OU2,

        # Parameter containing part of the name of a shared group to include users from.
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $SharedGroupFilter,

        # Parameter containing searchscope for get-aduser. Defaults to Subtree.
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("Base","0","OneLevel","1","Subtree","2")]
        $SearchScope = "Subtree"
    )

    Begin
    {
        IF($SharedGroupFilter) {$SharedGroupFilter="*"+$SharedGroupFilter+"*"}
    }
    Process
    {
        IF($OU2) {
            IF($SharedGroupFilter) {
		        $ShadowUsers=Get-ADGroupMember -Identity $ShadowGroup | Where-Object {$_.distinguishedName -NotMatch $OU -and $_.distinguishedName -NotMatch $OU2}
                $SharedGroupUsers=Get-ADGroup -Filter {name -like $SharedGroupFilter} -SearchBase "OU=Groups,DC=contoso,DC=com" | %{get-aduser -LDAPFilter "(memberOf=$_)"}
                IF($ShadowUsers) {
                    $ShadowUsers.distinguishedName | Where {$SharedGroupUsers.distinguishedName -notcontains $_} | ForEach-Object {Remove-ADPrincipalGroupMembership –Identity $_ –MemberOf $ShadowGroup –Confirm:$false}
                }
                Get-ADGroup -Filter {name -like $SharedGroupFilter} -SearchBase "OU=Groups,DC=contoso,DC=com" | %{get-aduser -LDAPFilter "(&(!memberOf=$ShadowGroup)(memberOf=$_))" | %{ForEach-Object {Add-ADPrincipalGroupMembership -Identity $_ -MemberOf $ShadowGroup}}}
            } else {
                Get-ADGroupMember –Identity $ShadowGroup | Where-Object {$_.distinguishedName –NotMatch $OU -and $_.distinguishedName –NotMatch $OU2} | ForEach-Object {Remove-ADPrincipalGroupMembership –Identity $_ –MemberOf $ShadowGroup –Confirm:$false}
            }
            Get-ADUser -SearchBase $OU -SearchScope $SearchScope -LDAPFilter "(&(!memberOf=$ShadowGroup)(!userAccountControl:1.2.840.113556.1.4.803:=2))" | ForEach-Object {Add-ADPrincipalGroupMembership –Identity $_ –MemberOf $ShadowGroup}        
            Get-ADUser -SearchBase $OU2 -SearchScope $SearchScope -LDAPFilter "(&(!memberOf=$ShadowGroup)(!userAccountControl:1.2.840.113556.1.4.803:=2))" | ForEach-Object {Add-ADPrincipalGroupMembership –Identity $_ –MemberOf $ShadowGroup}
	    } else {
            Get-ADGroupMember –Identity $ShadowGroup | Where-Object {$_.distinguishedName –NotMatch $OU -and $_.objectClass -NotMatch "Group"} | ForEach-Object {Remove-ADPrincipalGroupMembership –Identity $_ –MemberOf $ShadowGroup –Confirm:$false}
            Get-ADUser -SearchBase $OU -SearchScope $SearchScope -LDAPFilter "(&(!memberOf=$ShadowGroup)(!userAccountControl:1.2.840.113556.1.4.803:=2))" | ForEach-Object {Add-ADPrincipalGroupMembership –Identity $_ –MemberOf $ShadowGroup}        
        }
        
    }
}