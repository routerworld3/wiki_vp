In Microsoft Defender for Endpoint (MDE) on non-Windows platforms like Linux and macOS, antivirus and security configurations are controlled via the antivirusEngine portion (alongside companion top-level blocks like cloudService and features) inside the managed JSON configuration file (mdatp_managed.json) located at /etc/opt/microsoft/mdatp/managed/. [1, 2, 3] 
For Windows endpoints, configuration files are generally abstracted away into cloud-managed service policies via Microsoft Intune or Configuration Manager rather than edited locally as text config files. [4, 5] 
------------------------------
## Key Sections in the Configuration File and What Each Means
The top-level configuration areas and their specific functional sub-keys control the security posture:
## 1. antivirusEngine (Antivirus Core Preferences)
This section controls how the core scanning and protection engine operates on the system. [1, 3] 

* enforcementLevel: Controls the operational mode of the AV engine. Values typically include real_time (active protection and scanning), passive (EDR telemetry and threat visibility active, but no blocking/remediation), or disabled. [6, 7] 
* behaviorMonitoring: Enables or disables real-time behavioral analysis and process monitoring to block suspicious activity patterns. [7] 
* scanFileModifyPermissions: Dictates whether files are scanned when their permissions or attributes are modified.
* threatTypeSettings: Configures how specific threat classes (e.g., potentially_unwanted_application or archive_bomb) are handled—whether they are set to block, audit, or disabled. [8] 
* exclusionSettings / Exclusions: Manages paths, extensions, or processes that the antivirus engine should skip during scans to prevent performance conflicts with heavy applications. [9] 

## 2. cloudService (Cloud-Delivered Protection)
This section controls cloud intelligence integration for rapid, real-time threat lookup. [10] 

* enabled: Turns cloud-delivered protection on or off, allowing the agent to query Microsoft's cloud security intelligence for fast verdicts on unknown files.
* automaticDefinitionUpdateEnabled: Controls whether the client automatically fetches new security intelligence updates.
* automaticSampleSubmissionConsent: Dictates the level of telemetry or suspicious file sample sharing permitted back to Microsoft for analysis (e.g., safe or none). [7, 8, 11] 

## 3. networkProtection (Network and Web Security)

* Configures web threat defenses, blocking connections to malicious IP addresses, domains, or URLs based on smart filtering.

If you are working with a specific operating system environment like Linux, macOS, or Windows, let me know and I can provide a sample JSON or Intune policy template tailored to your requirements.

[1] [https://learn.microsoft.com](https://learn.microsoft.com/en-us/defender-endpoint/linux-preferences)
[2] [https://learn.microsoft.com](https://learn.microsoft.com/en-us/defender-endpoint/linux-preferences)
[3] [https://learn.microsoft.com](https://learn.microsoft.com/en-us/defender-endpoint/mac-preferences)
[4] [https://learn.microsoft.com](https://learn.microsoft.com/en-us/defender-endpoint/secure-controlled-configuration)
[5] [https://www.youtube.com](https://www.youtube.com/watch?v=q1EAcbl_K8E&t=36)
[6] [https://www.reddit.com](https://www.reddit.com/r/DefenderATP/comments/wkaiz1/ms_defender_on_linux/)
[7] [https://learn.microsoft.com](https://learn.microsoft.com/en-us/defender-endpoint/guidance-pen-testing-bas-linux)
[8] [https://techcommunity.microsoft.com](https://techcommunity.microsoft.com/discussions/microsoftdefenderatp/mde-configuration-for-linux-via-managed-json/4389095)
[9] [https://learn.microsoft.com](https://learn.microsoft.com/en-nz/answers/questions/5387984/defender-on-linux-removes-systemd-configuration-fi)
[10] [https://learn.microsoft.com](https://learn.microsoft.com/en-us/defender-endpoint/configure-network-connections-microsoft-defender-antivirus)
[11] [https://learn.microsoft.com](https://learn.microsoft.com/en-us/defender-endpoint/linux-support-offline-security-intelligence-update)
