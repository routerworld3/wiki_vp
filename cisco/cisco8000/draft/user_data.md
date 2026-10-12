## Console
```bash
Section: IOS configuration
aaa new-model
aaa authentication login CONSOLE-NONE none
aaa authorization exec CONSOLE-NONE none
line console 0
 privilege level 15
 login authentication CONSOLE-NONE
 authorization exec CONSOLE-NONE
 exit
```

## Console/SSH
```bash
configure terminal
!
username netadmin privilege 15 secret REPLACE_WITH_STRONG_PASSWORD
!
aaa new-model
aaa authentication login VTY-LOCAL local
aaa authorization exec VTY-LOCAL local
!
ip ssh version 2
!
ip ssh pubkey-chain
 username netadmin
  key-string
   ssh-rsa REPLACE_WITH_COMPLETE_PUBLIC_KEY_BASE64
  exit
 exit
exit

configure terminal
ip ssh pubkey-chain
 username netadmin
  key-hash ?
!
line vty 0 15
 login authentication VTY-LOCAL
 authorization exec VTY-LOCAL
 transport input ssh
 exec-timeout 10 0
!
end
```

 
