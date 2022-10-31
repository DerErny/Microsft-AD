#Active Directory Passwort Policy:
$MaxPasswordAge = 180		#Max Password age in days
$WarningLevel = 5		#Warn Users XX Days before Password expires
$StopWarningLevel = 0 		#Stop sending Mails to User XX Days after Password is expired (kind of AntiSpam)

$ExpirePasswordList = ' '	# Clearing the Variable $ExpirePasswordList
$MailAddress = ' ' 		#Clearing Variable  $MailAddress
                            	# Has to be 0. Negative count doesn´t work right
#Mail Settings:
$SMTPServer = "meinmail.server.de"
$From = "support@mail-adresse.de"
$Subject = "Ihr Passwort läuft ab"

#Message Template (Mailbody) as a String. Variables are written out.  <br> creates a new Line (default HTML)
# Informs about Days left until the Password has to been changed. Change $DaysBeforePasswordchange with $PasswordExpireDate to get the Date into the Mail (MM/DD/YYYY)
function New-MailBody ($name, $DaysBeforePasswordchange, $PasswordExpireDate)
 {
   $Mailbody = "
    <html>
	<head>
	</head>
	<body>
	Guten Tag $name,
	<br>
	<br>
	Ihr Kennwort läuft in $DaysBeforePasswordchange Tagen ab. Bitte ändern Sie Ihr Kennwort zeitnah.
	<br>
	<br>
	Mit freundlichen Grüßen <br>
	Support
	<br>
	<br>
	</body>
   "
   return $Mailbody
 }

#Import all active AD-Users. Sort out User where Password never expire
$AllADUsers = Get-ADUser -Filter {Enabled -eq $True -and PasswordNeverExpires -eq $False} -Properties PasswordLastSet,mail


#Calculate expirering passwords and store them in an object
$today = get-date
$ExpirePasswordList =@() 
foreach ($ADUser in $AllADUsers)
 {
  $PasswordLastSet = ''		 #Empty PasswordLastSet
  $GivenName = $ADUser.GivenName #Write GivenName to Variable
  $name = $ADUser.name 		 #Write Full Name to Variable 
  $MailAddress = $ADUser.mail 	 #Write Users Mailadress to Variable
 
  $PasswordLastSet = $ADUser.PasswordLastSet #Write Date of Last Password Change to Variable 
  if ($PasswordLastSet) { # Starts only if PasswordLastSet is set. Users who never logged on didn´t set any Password
  
  $PasswordExpireDate = $PasswordLastSet.AddDays(+$MaxPasswordAge)
  
  $DaysBeforePasswordchange = ($PasswordExpireDate - $today).Days
    
   if ($DaysBeforePasswordchange -le $WarningLevel)
    {
     if ($DaysBeforePasswordchange -le $StopWarningLevel){ #Skip mail creation when Password is already expired
     } else{
       $ExpirePasswordList += new-object PSObject -property @{Name=$name;MailAddress=$MailAddress;DaysBeforePasswordchange=$DaysBeforePasswordchange;PasswordExpireDate=$PasswordExpireDate} 
     }
    }
   }
 }

#Filter Users with Mailaddresses
$ExpirePasswordList = $ExpirePasswordList | Where {$_.mailaddress}

#Send mail to every user with expired password
foreach ($ADUser in $ExpirePasswordList)
 {
  $GivenName = $ADUser.GivenName 	
  $name = $ADUser.name		 	
  $MailAddress = $ADUser.MailAddress	
  $DaysBeforePasswordchange = $ADUser.DaysBeforePasswordchange	 
  $PasswordExpireDate = $ADUser.PasswordExpireDate
  
  $Body = New-MailBody $name $DaysBeforePasswordchange $PasswordExpireDate # Creates a new MialBody in HTML Format (jump to Line 16)
   
  # $Body | out-file -filepath C:\temp\dump.txt # Line to Dump the mail to a TXT File
  # $MailAddress = 'mail@address.de' Line to change the mailadress of every Mail to the same one. For Test Porpuse only.
  
  Send-MailMessage -SmtpServer $SMTPServer -To $MailAddress -From $From -Body $Body -BodyAsHtml -Subject $Subject -encoding ([System.Text.Encoding]::UTF8)
 }
