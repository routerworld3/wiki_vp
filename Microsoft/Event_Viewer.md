Below are two example PowerShell approaches you can use to filter and parse Event ID 4771 (“Kerberos pre-authentication failed”) from the Security event log, extracting key fields such as **Account Name**, **Client Address**, **Ticket Options**, and **Failure Code**.

---

## 1. Quick Parsing Using `Get-WinEvent -FilterHashtable` and Event Properties

Windows events from the “Microsoft-Windows-Security-Auditing” provider typically include the event data (e.g., Account Name, Client Address, etc.) in the `.Properties` collection of the returned objects. For Event ID 4771, the order of `.Properties` is generally consistent.

> **Important**: The exact index mapping of `.Properties[...]` can sometimes vary by OS version or additional instrumentation. Always verify the indexes in your environment if you rely on property positions.

### Script Example

```powershell
# This script uses Get-WinEvent with a FilterHashtable 
# to return only Event ID 4771 from the Security log.

Get-WinEvent -LogName Security -FilterHashtable @{
    ProviderName = "Microsoft-Windows-Security-Auditing"
    Id           = 4771
} |
ForEach-Object {
    # For event 4771, a typical .Properties order is:
    #  0: Security ID
    #  1: Account Name
    #  2: Account Domain
    #  3: Logon ID
    #  4: Service Name
    #  5: Service ID
    #  6: Ticket Options
    #  7: Failure Code
    #  8: Client Address (IP)
    #  9: Client Port
    # 10: Pre-Authentication Type
    # 11: ? (Certificate info, etc., if present)

    [PSCustomObject]@{
        TimeCreated            = $_.TimeCreated
        SecurityID             = $_.Properties[0].Value
        AccountName            = $_.Properties[1].Value
        ServiceName            = $_.Properties[4].Value
        ClientAddress          = $_.Properties[8].Value
        ClientPort             = $_.Properties[9].Value
        TicketOptions          = $_.Properties[6].Value
        FailureCode            = $_.Properties[7].Value
        PreAuthenticationType  = $_.Properties[10].Value
    }
} | Format-Table -AutoSize
```

**What this does**:  
1. Uses `Get-WinEvent` to query the Security log for the specific **ProviderName** and **Event ID 4771**.  
2. Loops through each event (`ForEach-Object`) and creates a `[PSCustomObject]` with the fields you want.  
3. Finally, outputs them in a table.

---

## 2. Parsing Using Event XML

If you prefer to avoid relying on the specific order of `.Properties`, you can parse the event data by name from the underlying XML. This is often more robust if the property order changes over time.

### Script Example

```powershell
Get-WinEvent -LogName Security -FilterHashtable @{
    ProviderName = "Microsoft-Windows-Security-Auditing"
    Id           = 4771
} |
ForEach-Object {
    # Convert the event to XML
    $xml = [xml]$_.ToXml()

    # $xml.Event.EventData.Data is an array of <Data> nodes
    # Each <Data> node has a 'Name' attribute and text (#text)
    # Common names in 4771:
    #   TargetUserName  => Account Name
    #   IpAddress       => Client Address
    #   TicketOptions   => Ticket Options
    #   FailureCode     => Failure Code
    #   ServiceName     => Service Name
    #   ...
    
    $eventData   = $xml.Event.EventData.Data

    # Extract by Name
    $accountName    = ($eventData | Where-Object { $_.Name -eq 'TargetUserName' }).'#text'
    $clientAddress  = ($eventData | Where-Object { $_.Name -eq 'IpAddress'    }).'#text'
    $ticketOptions  = ($eventData | Where-Object { $_.Name -eq 'TicketOptions'}).'#text'
    $failureCode    = ($eventData | Where-Object { $_.Name -eq 'FailureCode'  }).'#text'

    [PSCustomObject]@{
        TimeCreated    = $_.TimeCreated
        AccountName    = $accountName
        ClientAddress  = $clientAddress
        TicketOptions  = $ticketOptions
        FailureCode    = $failureCode
    }
} | Format-Table -AutoSize
```

**What this does**:  
1. Similar to the first example, but converts each event to XML with `[xml]$_.ToXml()`.  
2. Looks at the `<EventData><Data>` elements by matching the `Name` attributes.  
3. Collects the values from the `#text` property of each `<Data>` node.

---

## Choosing Your Approach

- **Using `Properties[Index]`:** Quick and easy, but you must validate the property positions in your environment.  
- **Using XML parsing by `Name`:** More robust if property order can vary, but slightly more verbose.  

---

## Filtering on Specific Account Name or Client Address

If you want to further **filter** on a specific Account Name or Client Address, you can add a `Where-Object` clause:

```powershell
Get-WinEvent -LogName Security -FilterHashtable @{
    ProviderName = "Microsoft-Windows-Security-Auditing"
    Id           = 4771
} |
Where-Object {
    # Example: filter by a specific AccountName or ClientAddress
    $_.Properties[1].Value -eq 'jdoe' -or
    $_.Properties[8].Value -eq '192.168.1.100'
} |
ForEach-Object {
    ...
}
```

Adjust the indexes (or XML approach) as needed for the fields you want to match.

---

### Summary

These scripts give you a flexible starting point to collect **Event ID 4771** records from the Windows Security log and extract details such as **Account Name**, **Client Address**, **Ticket Options**, and **Failure Code**. You can tailor the scripts to your environment, add filtering, export the data (e.g., to CSV), or integrate with larger incident-response workflows.

## Resources
 
https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4771#kerberos-preauthentication-types

https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4771#security-monitoring-recommendations

https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4771