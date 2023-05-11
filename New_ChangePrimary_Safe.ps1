#this is the app registration piece

$tenantId =  ""
$appId = ""

$AutomationIDClientId = 'Your Azure Automation Account Identity'

$secret =  ""

$graphuri = "https://graph.microsoft.com"

$oAuthUri = "https://login.microsoftonline.com/$TenantId/oauth2/token"

$gauthBody = [Ordered] @{

resource = "$graphuri"

client_id = "$appId"

client_secret = "$secret"

grant_type = 'client_credentials'

}

 

$authResponse = Invoke-RestMethod -Method Post -Uri $oAuthUri -Body $gauthBody -ErrorAction Stop

$gtoken = $authResponse.access_token

$Header = @{

'Content-Type' = 'application/json'

Accept = 'text/html, application/json'

 Authorization = "Bearer $gtoken"

}

 
 #App Registration Permissions should include the following: DeviceManagementManagedDevices.ReadWrite.All (Application) and User.ReadAll (Application)

 

#beginning of the actual script below

#The only piece missing is getting the $userID because that's the only way Intune can apply the change.

 

#notes for the changes below:

#https://techcommunity.microsoft.com/t5/intune-customer-success/understanding-the-intune-device-object-and-user-principal-name/ba-p/3657593

#https://techcommunity.microsoft.com/t5/intune-customer-success/change-the-intune-primary-user-public-preview-now-available/ba-p/1221264

 

#this part is taking the upn to get the userID (NEEDS WORK)

 

#Get Logged In User

$USERupn = whoami /upn

 

#deviceID

#Get Intune Device ID From registry (this might require 64-bit powershell)

$Reg = Get-ChildItem HKLM:\SOFTWARE\Microsoft\Enrollments -Recurse -Include "MS DM Server"

$IntDevID = Get-ItemPropertyValue -Path Registry::$Reg -Name EntDMID

 

 

 

 

Function Get-AADUser(){

 

    <#

    .SYNOPSIS

    This function is used to get AAD Users from the Graph API REST interface

    .DESCRIPTION

    The function connects to the Graph API Interface and gets any users registered with AAD

    .EXAMPLE

    Get-AADUser

    Returns all users registered with Azure AD

    .EXAMPLE

    Get-AADUser -userPrincipleName user@domain.com

    Returns specific user by UserPrincipalName registered with Azure AD

    .NOTES

    NAME: Get-AADUser

    #>

   

    [cmdletbinding()]

   

    param

    (

        $userPrincipalName,

        $Property

    )

   

    # Defining Variables

    $graphApiVersion = "v1.0"

    $User_resource = "users"

       

        try {

           

            if($userPrincipalName -eq "" -or $userPrincipalName -eq $null){

           

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)"

            (Invoke-RestMethod -Uri $uri -Headers $Header -Method Get).Value

           

            }

   

            else {

               

                if($Property -eq "" -or $Property -eq $null){

   

                $uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)/$userPrincipalName"

                Write-Verbose $uri

                Invoke-RestMethod -Uri $uri -Headers $Header -Method Get

   

                }

   

                else {

   

                $uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)/$userPrincipalName/$Property"

                Write-Verbose $uri

                (Invoke-RestMethod -Uri $uri -Headers $Header -Method Get).Value

   

                }

   

            }

       

        }

   

        catch {

   

        $ex = $_.Exception

        $errorResponse = $ex.Response.GetResponseStream()

        $reader = New-Object System.IO.StreamReader($errorResponse)

        $reader.BaseStream.Position = 0

        $reader.DiscardBufferedData()

        $responseBody = $reader.ReadToEnd();

        Write-Host "Response content:`n$responseBody" -f Red

        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"

        write-host

        break

   

        }

   

    }

 

   $AADuserID =  (Get-AADUser -userPrincipalName "$Userupn").Id

 

# this part is the setting up the primary user on the device using graph api

function Set-IntuneDevicePrimaryUser {

 

    <#

    .SYNOPSIS

    This updates the Intune device primary user

    .DESCRIPTION

    This updates the Intune device primary user

    .EXAMPLE

    Set-IntuneDevicePrimaryUser

    .NOTES

    NAME: Set-IntuneDevicePrimaryUser

    #>

   

    [cmdletbinding()]

   

    param

    (

    [parameter(Mandatory=$true)]

    [ValidateNotNullOrEmpty()]

    $IntuneDeviceId,

    [parameter(Mandatory=$true)]

    [ValidateNotNullOrEmpty()]

    $userId

    )

        $graphApiVersion = "beta"

        $Resource = "deviceManagement/managedDevices('$IntuneDeviceId')/users/`$ref"

   

        try {

            

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

   

            $userUri = "https://graph.microsoft.com/$graphApiVersion/users/" + $userId

   

            $id = "@odata.id"

            $JSON = @{ $id="$userUri" } | ConvertTo-Json -Compress

 

            #special note: I changed the $authToken to $Headers because I already have that from above.

            Invoke-RestMethod -Uri $uri -Headers $Header -Method Post -Body $JSON -ContentType "application/json"

   

        } catch {

            $ex = $_.Exception

            $errorResponse = $ex.Response.GetResponseStream()

            $reader = New-Object System.IO.StreamReader($errorResponse)

            $reader.BaseStream.Position = 0

            $reader.DiscardBufferedData()

            $responseBody = $reader.ReadToEnd();

            Write-Host "Response content:`n$responseBody" -f Red

            Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"

            throw "Set-IntuneDevicePrimaryUser error"

        }

   

    }

 

# start the adding of the user here:

#Set-IntuneDevicePrimaryUser -IntuneDeviceId "916c4d89-cd82-46bc-8c74-088c5675a571" -userId "$AADuserID"


#"$intDevID","$aaduserID" | Out-File C:\scripttest.txt -Force

Set-IntuneDevicePrimaryUser -IntuneDeviceId "$IntDevID" -userId "$AADuserID"
