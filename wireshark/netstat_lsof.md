# lsof 
``` bash
lsof -p 20033 #(which files this process ID 20033 has open)
Lsof -p 'pgrep ABC' (#(which files this process ID 20033 has open)
Lsof /var/log/access.log #(which process have this file open)
Lsof -p PID | grep .so (# which shared library this program using)
Lsof grep libname.so (# which process still have this library open)
Lsof -u XYZ (#which files does user XYZ have open?)
Lsof -u XYZ -i #(Network Only)
Lsof -i:80  (#Which process is listening on Port x/80 or using protocol tcp)
Lsof -i tcp 
Lsof +L1 (# We delete files but it still open by process disk size does not Increase)


lsof      # Complete list
lsof -i :22    # Filter single TCP port
lsof [email protected]:22 # Filter single connection endpoint
lsof -u <user>   # Filter per user
lsof -c <name>   # Filter per process name
lsof -p 12345    # Filter by PID
lsof /etc/hosts   # Filter single file
```
