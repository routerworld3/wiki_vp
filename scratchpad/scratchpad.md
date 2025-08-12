# Drop TCP when PPv2 header says src=1.1.1.1
drop tcp any any -> $HOME_NET any (
  msg:"DROP PPv2 src=1.1.1.1 (IPv4/TCP)";
  flow:to_server,established;
  # PPv2 signature "\r\n\r\n\0\r\nQUIT\n" (12 bytes) + ver/cmd 0x21 + fam/proto 0x11
  content:"|0D 0A 0D 0A 00 0D 0A 51 55 49 54 0A 21 11|"; offset:0; depth:14;
  # Skip the 2-byte length field, then match the 4-byte src IPv4 address (1.1.1.1)
  content:"|01 01 01 01|"; distance:2; within:4;
  classtype:not-suspicious; sid:420011001; rev:1;
)



tcp[0:12] == 0d:0a:0d:0a:00:0d:0a:51:55:49:54:0a


06:B2:59:27:C4:2A:72:16:31:C1:EF:D9:43:1E:64:8F:A6:2E:1E:39
nonnnpi_endpoints

aws_security_group.endpoints.id

aws_security_group.nonnnpi_endpoints.id


##############################################################################
MO is Mission Owner 
VDMS sometimes reference as Shared Services 
VDSS Central TGW have Two TGW one for NNPI and second for nonnnpi TGW This can be reference as Central TGW ( nnpi and nonnnpi) 
VDMS TGW refrence as Shared Service TGW or Shared_SVC_TGW

Theare are two kind of Mission Owner.

- Small Mission owner with Direct VPC Peering with VDSS TGW 
    MO can have nnpi and nonnnpi VPC & each VPC will peer with nnpi and nonnnpi VDSS TGW
	
- Big Mission Owner with TGW Which Peers with VDSS NNNPI and nonnnpi TGW 


1 Small MO  VPC Direct Connection to TGW  

Each MO VPC Will get 2 TGW Attachment 

one for Central VDSS TGW nnpi or non nnpi Depending on MO VPC (nnnpi or non nnpi) 
second to Shared Service TGW or Shared_SVC_TGW

MO VPC Route Table :
- Default Route ===>VDSS TGW(nnpi or nnpi depending on mission owner vpc) 
- VDMS Shared Services CIDR Bloc  ====>Shared_SVC_TGW ( Static Routes ) 

Any time New CIDR is added to VDMS or Shared Services  MO VPC Needs To be Updated.


##################################################################################
Shared Services TGW Route Table 
Two TGW RT 

MO RT
-  MO VPC or TGW will associate to this RT Only
-  Routes to VDMS Propagated

VDMS RT 
  - VDMS VPC is associated 
  - All MO VPC Routes Propagated
  - All MO TGW Static Routes [Static Routes Required]
  
###########################################################################################################
2 Bigger MO TGW Peering to Shared Services TGW nnpi and nonnnpi , two peering for Mixed workload 

Assumption is MO have Single TGW is shared b/w nnpi and nonnnpi VPC 

MO VPC Route Table 
- Route to MO TGW 

MO TGW Route Tables 

Any time New CIDR is added to VDMS or Shared Services  MO VPC Needs To be Updated.

- MO NNPI RT 
  - Associated with MO NNPI VPC 
  - Static Route for Shared Services toward Shared_SVC_TGW 
  - Static Default Route to NNNPI TGW in VDSS
  - Dynmaic MO NNPI VPC Route Propagated
  
- - MO nonNNPI RT 
  - Associated with MO nonNNPI VPC 
  - Static Route for Shared Services toward Shared_SVC_TGW 
  - Static Default Route to non NNNPI TGW in VDSS
  - Dynmaic MO nonNNPI VPC Route Propagated
  
-  Retrun RT 
  - Associated with VDSS and Shared Service TGW Peering 
  - All Propogated Routes for the NNPI and Non NNPI VPC 
  
################################################################################################
