Section: IOS configuration
aaa new-model
aaa authentication login CONSOLE-NONE none
aaa authorization exec CONSOLE-NONE none
line console 0
 login authentication CONSOLE-NONE
 authorization exec CONSOLE-NONE
 exit

 
