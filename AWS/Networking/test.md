

Defining rule actions in AWS Network Firewall
 PDF
 RSS
Focus mode
The rule action setting tells AWS Network Firewall how to handle a packet that matches the rule's match criteria.
Actions for stateless rules
The action options for stateless rules are the same as for the firewall policy's default stateless rule actions.
You are required to specify one of the following options:
•	Pass – Discontinue all inspection of the packet and permit it to go to its intended destination.
•	Drop – Discontinue all inspection of the packet and block it from going to its intended destination.
•	Forward to stateful rules – Discontinue stateless inspection of the packet and forward it to the stateful rule engine for inspection.
Additionally, you can optionally specify a named custom action to apply. For this action, Network Firewall assigns a dimension to Amazon CloudWatch metrics with the name set to CustomAction and a value that you specify. For more information, see AWS Network Firewall metrics in Amazon CloudWatch.
After you define a named custom action, you can use it by name in the same context as where you defined it. You can reuse a custom action setting among the rules in a rule group and you can reuse a custom action setting between the two default stateless custom action settings for a firewall policy.
Stateful actions
The actions that you specify for your stateful rules help determine the order in which the Suricata stateful rules engine processes them. Network Firewall supports the Suricata rule actions pass, drop, reject, and alert. By default, the engine processes rules in the order of pass action, drop action, reject action, and then finally alert action. Within each action, you can set a priority to indicate processing order. For more information, see Managing evaluation order for Suricata compatible rules in AWS Network Firewall.
Stateful rules can send alerts to the firewall's logs, if you have logging configured. To see the alerts, you must enable logging for the firewalls that use the rules. Logging incurs additional costs. For more information, see Logging network traffic from AWS Network Firewall.
The options for stateful action settings vary by rule type.
Standard rules and Suricata compatible strings
You specify one of the following action options for both the rules that you provide in Suricata compatible strings and the rules that you specify using the standard stateless rules interface in Network Firewall. These options are a subset of the action options that are defined by Suricata. For more information, see Working with stateful rule groups in AWS Network Firewall.
•	Pass – Discontinue inspection of the matching packet and permit it to go to its intended destination. Rules with pass action are evaluated before rules with other action settings.
•	Drop or Alert– Evaluate the packet against all rules with drop or alert action settings. If the firewall has alert logging configured, send a message to the firewall's alert logs for each matching rule. The first log entry for the packet will be for the first rule that matched the packet.
After all rules have been evaluated, handle the packet according to the the action setting in the first rule that matched the packet. If the first rule has a drop action, block the packet. If it has an alert action, continue evaluation.
•	Reject – Drop traffic that matches the conditions of the stateful rule and send a TCP reset packet back to sender of the packet. A TCP reset packet is a packet with no payload and a RST bit contained in the TCP header flags. Reject is available only for TCP traffic. This option doesn't support FTP and IMAP protocols.
Note
Matching a drop or alert rule for a packet doesn't necessarily mean the end of rule processing for that packet. The engine continues evaluating other rules for matches. For example, if there's a drop match that drops a packet, the packet can still go on to match an alert rule that generates alert logs. Matching an alert rule also doesn't imply a pass. The packet can go on to match a drop rule, and drop the packet after it's previously matched an alert rule.
For information about what you can do to manage the evaluation order of your stateful rules, see Managing evaluation order for Suricata compatible rules in AWS Network Firewall.
Domain lists
The domain list rule group has one action setting at the rule group level. You specify one of the following options:
•	Allow – Indicates that the domain name list is to be used as an allow list for all traffic that matches the specified protocols. For matching packets, discontinue inspection of the packet and permit it to pass to its intended destination. For non-matching packets, discontinue inspection of the packet, block it from going to its intended destination, and send a message to the firewall's alert logs if the firewall has alert logging configured.
•	Deny – Indicates that the domain name list is to be used as a deny list for traffic that matches the specified protocols. For matching packets, discontinue inspection of the packet, block it from going to its intended destination, and send a message to the firewall's alert logs if the firewall has alert logging configured. For non-matching packets, take no action.

Managing evaluation order for Suricata compatible rules in AWS Network Firewall
 PDF
 RSS
Focus mode
You can configure and manage the evaluation order of the rules in your Suricata compatible stateful rule groups.

All of your stateful rule groups are provided to the rule engine as Suricata compatible strings. Suricata can evaluate stateful rule groups by using the default rule group ordering method, or you can set an exact order using the strict ordering method. We recommend that you use strict order because it lets you specify the exact order that you'd like the stateful engine to evaluation your rules. The settings for your rule groups must match the settings for the firewall policy that they belong to.

Action order

If your firewall policy is set up to use action order rule group ordering, the action order by which Suricata evaluates stateful rules is determined by the following settings, listed in order of precedence:

The Suricata action specification. This takes highest precedence.

Actions are processed in the following order:

pass

drop

reject

alert

Note
If a packet within a flow matches a rule containing pass action, then Suricata doesn't scan the other packets in that flow and it passes the unscanned packets.

For more information about the action specification, see Suricata.yaml: Action-order in the Suricata User Guide.

The Suricata priority keyword. Within a specific action group, you can use the priority setting to indicate the processing order. By default, Suricata processes from the lowest numbered priority setting on up. The priority keyword has a mandatory numeric value ranging from 1 to 255. Note that the priority keyword is only valid using the default action order.

For more information about priority, see Suricata.yaml: Action-order in the Suricata User Guide.

For example, Suricata evaluates all pass rules before evaluating any drop, reject, or alert rules by default, regardless of the value of priority settings. Within all pass rules, if priority keywords are present, Suricata orders the processing according to them.

The protocol layer does not impact the rule evaluation order by default. If you want to avoid matching against lower-level protocol packets before higher-level application protocols can be identified, consider using the flow keyword in your rules. This is needed because, for example, a TCP rule might match on the first packet of a TCP handshake before the stateful engine can identify the application protocol. For information about the flow keyword, see Flow Keywords.

For examples of default rule order management, see Stateful rules examples: manage rule evaluation order.

For additional information about evaluation order for stateful rules, see the following topics in the Suricata User Guide:

Suricata.yaml: Action-order

Meta Keywords: priority

Strict evaluation order

If your firewall policy is set up to use strict ordering, Network Firewall allows you the option to manually set a strict rule group order. With strict ordering, the rule groups are evaluated by order of priority, starting from the lowest number, and the rules in each rule group are processed in the order in which they're defined.

When you choose Strict for your rule order, you can choose one or more Default actions. Note that this does not refer to default action rule ordering, but rather, to the default actions that Network Firewall takes when following your strict, or exact, rule ordering. The default actions are as follows:

Drop actions
If you have rules that match application layer data, such as those that evaluate HTTP headers, a default drop action might trigger earlier than you want. This can happen when the data that your rules match against spans multiple packets, because a default drop action can apply to a single packet. For this case, don't choose any default drop action and instead use drop rules that are specific to the application layer.

Choose none or one. You can't choose both.

Drop all – Drops all packets.

Drop established – Drops only the packets that are in established connections. This allows the layer 3 and 4 connection establishment packets that are needed for the upper-layer connections to be established, while dropping the packets for connections that are already established. This allows application-layer pass rules to be written in a default-deny setup without the need to write additional rules to allow the lower-layer handshaking parts of the underlying protocols.

Choose this option when using strict order for your own domain list rule groups because Network Firewall requires an established connection in order to evaluate whether to pass or drop the packets for domain lists.

For other protocols, such as UDP, Suricata considers the connection established only after seeing traffic from both sides of the connection.

Alert actions
Choose none, one, or both.

Alert all - Logs an ALERT message on all packets. This does not drop packets, but alerts you to what would be dropped if you were to choose Drop all.

Alert established - Logs an ALERT message on only the packets that are in established connections. This does not drop packets, but alerts you to what would be dropped if you were to choose Drop established.

For more information about logging network traffic, see Logging network traffic from AWS Network Firewall.

Limitations and caveats for stateful rules in AWS Network Firewall
 PDF
 RSS
Focus mode
AWS Network Firewall stateful rules are Suricata compatible. Most Suricata rules work out of the box with Network Firewall. Your use of Suricata rules with Network Firewall has the restrictions and caveats listed in this section.
Suricata features that Network Firewall doesn't support
The following Suricata features are not supported by Network Firewall:
•	Datasets. The keywords dataset and datarep aren't allowed.
•	ENIP/CIP keywords.
•	File extraction. File keywords aren't allowed.
•	FTP-data protocol detection.
•	IP reputation. The iprep keyword is not allowed.
•	Lua scripting.
•	Rules actions except for pass, drop, reject, and alert. Pass, drop, reject, and alert are supported. For additional information about stateful rule actions, see Stateful actions.
•	SCTP protocol.
•	Thresholding.
•	IKEv2 protocol.
Suricata features that Network Firewall supports with caveats
The following Suricata features have caveats for use with Network Firewall:
•	If you want a rule group to use settings for HOME_NET and EXTERNAL_NET that are different from those that are set for the firewall policy, you must explicitly set both of these variables.
o	In a firewall policy's variables, you can set a custom value for HOME_NET. The default HOME_NET setting is the CIDR of the inspection VPC. The policy's EXTERNAL_NET setting is always the negation of the policy's HOME_NET setting. For example, if the HOME_NET is 11.0.0.0, the EXTERNAL_NET is set to !11.0.0.0.
o	In a rule group's variables, you can set custom values for both HOME_NET and EXTERNAL_NET. If you explicitly set rule group variables, those are used. Otherwise, rule group variables inherit their settings from the corresponding policy variables.
This means that, if you don't specify the rule group's EXTERNAL_NET, it inherits the setting from the policy's EXTERNAL_NET setting, regardless of the value of the rule group's HOME_NET setting.
For example, say you set the rule group's HOME_NET to 10.0.0.0, and the firewall policy's HOME_NET to 11.0.0.0. If you don't set the rule group's EXTERNAL_NET, then Network Firewall sets it to !11.0.0.0, based on the policy's HOME_NET setting.
•	The AWS Network Firewall stateful inspection engine supports inspecting inner packets for tunneling protocols such as Generic Routing Encapsulation (GRE). If you want to block the tunneled traffic, you can write rules against the tunnel layer itself or against the inner packet. Due to the service inspecting the different layers, you might see flows and alerts for the packets within the tunnel.
•	To create a rule that requires a variable, you must specify the variable in the rule group. Without the required variables, the rule group isn't valid. For an example of a rule group that's configured with variables, see Stateful rules examples: rule variables.
•	In payload keywords, the pcre keyword is only allowed with content, tls.sni, http.host, and dns.query keywords.
•	The priority keyword is not supported for rule groups that evaluate rules using strict evaluation order.
•	When you use a stateful rule with a layer 3 or 4 protocol such as IP or TCP, and you don't include any flow state context, for example "flow:not_established", then Suricata treats this rule as an IP-only rule. Suricata only evaluates IP-only rules for the first packet in each direction of the flow. For example, Suricata will process the following rule as an IP-only rule:
pass tcp $HOME_NET any -> [10.0.0.0/8] $HTTPS_PORTS (sid: 44444; rev:2;)
However, if the destination IP contains a !, then Suricata treats this as per the protocol specified in the rule. Suricata will process the following rule as a TCP rule.
pass tcp $HOME_NET any -> [!10.0.0.0/16] $HTTPS_PORTS (sid: 44444; rev:2;)
Logging network traffic from AWS Network Firewall
 PDF
 RSS
Focus mode
You can configure AWS Network Firewall logging for your firewall's stateful engine. Logging gives you detailed information about network traffic, including the time that the stateful engine received a packet, detailed information about the packet, and any stateful rule action taken against the packet. The logs are published to the log destination that you've configured, where you can retrieve and view them.
Note
Firewall logging is only available for traffic that you forward to the stateful rules engine. You forward traffic to the stateful engine through stateless rule actions and stateless default actions in the firewall policy. For information about these actions settings, see Firewall policy settings in AWS Network Firewall and Defining rule actions in AWS Network Firewall.
Metrics provide some higher-level information for both stateless and stateful engine types. For more information, see AWS Network Firewall metrics in Amazon CloudWatch.
You can record the following types of logs from your Network Firewall stateful engine.
•	Flow logs are standard network traffic flow logs. Each flow log record captures the network flow for a specific standard stateless rule group.
•	Alert logs report traffic that matches your stateful rules that have an action that sends an alert. A stateful rule sends alerts for the rule actions DROP, ALERT, and REJECT. For more information, see Stateful actions.
•	TLS logs report events that are related to TLS inspection. These logs require the firewall to be configured for TLS inspection. For information, see Inspecting SSL/TLS traffic with TLS inspection configurations in AWS Network Firewall.
You can use the same or different logging destination for each log type. You enable logging for a firewall after you create it. For information about how to do this, see Updating a AWS Network Firewall logging configuration.
Contents of a AWS Network Firewall log
Focus mode
The Network Firewall logs contain the following information:

firewall_name – The name of the firewall that's associated with the log entry.

availability_zone – The Availability Zone of the firewall endpoint that generated the log entry.

event_timestamp – The time that the log was created, written in epoch seconds at Coordinated Universal Time (UTC).

event – Detailed information about the event. This information includes the event timestamp converted to human readable format, event type, network packet details, and, if applicable, details about the stateful rule that the packet matched against.

Alert and flow events – Alert and flow events are produced by Suricata, the open source threat detection engine that the stateful rules engine runs on. Suricata writes the event information in the Suricata EVE JSON output format, with the exception of the AWS managed tls_inspected attribute.

Flow log events use the EVE output type netflow. The log type netflow logs uni-directional flows, so each event represents traffic going in a single direction.

Alert log events using the EVE output type alert.

If the firewall that's associated with the log uses TLS inspection and the firewall's traffic uses SSL/TLS, Network Firewall adds the custom field "tls_inspected": true to the log. If your firewall doesn't use TLS inspection, Network Firewall omits this field.

For detailed information about these Suricata events, see EVE JSON Output in the Suricata User Guide.

TLS events – TLS events are produced by a dedicated stateful TLS engine, which is separate from Suricata. TLS events have the output type tls. The logs have a JSON structure that's similar to the Suricata EVE output.

These events require the firewall to be configured for TLS inspection. For information, see Inspecting SSL/TLS traffic with TLS inspection configurations in AWS Network Firewall.

TLS logs report the following types of errors:

TLS errors, with the custom field "tls_error": containing the error details. Currently, this category includes Server Name Indication (SNI) mismatches and SNI naming errors. Typically these errors are caused by problems with customer traffic or with the customer's client or server. For example, errors caused when the client hello SNI is NULL or doesn't match the subject name in the server certificate.

Revocation check errors, with the custom field "revocation_check": containing the check failure details. These report outbound traffic that fails the server certificate revocation check during TLS inspection. This requires the firewall to be configured with TLS inspection for outbound traffic, and for the TLS inspection to be configured to check the certificate revocation status. The logs include the revocation check status, the action taken, and the SNI that the revocation check was for. For information about configuring certificate revocation checking, see Using SSL/TLS certificates with TLS inspection configurations in AWS Network Firewall.

For detailed information about these Suricata events, see EVE JSON Output in the Suricata User Guide.

Example alert log entry
The following listing shows an example alert log entry for Network Firewall.


{
      "firewall_name":"test-firewall",
      "availability_zone":"us-east-1b",
      "event_timestamp":"1602627001",
      "event":{
          "timestamp":"2020-10-13T22:10:01.006481+0000",
          "flow_id":1582438383425873,
          "event_type":"alert",
          "src_ip":"203.0.113.4",
          "src_port":55555,
          "dest_ip":"192.0.2.16",
          "dest_port":111,
          "proto":"TCP",
          "alert":{
              "action":"allowed",
              "signature_id":5,
              "rev":0,
              "signature":"test_tcp",
              "category":"",
              "severity":1
          }
      }
  }
Example TLS log entry
The following listing shows an example TLS log entry for a failed certificate revocation check.
{
    "firewall_name": "egress-fw",
    "availability_zone": "us-east-1d",
    "event_timestamp": 1708361189,
    "event": {
        "src_ip": "10.0.2.53",
        "src_port": "55930",
        "revocation_check": {
            "leaf_cert_fpr": "1234567890EXAMPLE0987654321",
            "status": "REVOKED",
            "action": "DROP"
        },
        "dest_ip": "54.92.160.72",
        "dest_port": "443",
        "timestamp": "2024-02-19T16:46:29.441824Z",
        "sni": "revoked-rsa-dv.ssl.com"
    }
}

Examples of stateful rules for Network Firewall
Focus mode
This section lists examples of Suricata compatible rules that could be used with AWS Network Firewall.
Note
Examples are not intended to be used in your Network Firewall configuration exactly as they are listed.
The examples provide general information and sample rule specifications for common use cases. Before using any rule from these examples or elsewhere, test and adjust it carefully to be sure that it fits your needs. It's your responsibility to ensure that each rule that you use is suited to your specific use case and functioning the way that you want it to.
Stateful rules examples: allow traffic
Note
Before using any example rule, test and adapt it to your needs.
The examples in this section contain examples that allow specified traffic.
Allow access to any ssm. Server Name Indication (SNI) ending with .amazonaws.com
Allows access to any domain that begins with ssm. and ends with .amazonaws.com (http://amazonaws.com/).
pass tls $HOME_NET any -> $EXTERNAL_NET any (ssl_state:client_hello; tls.sni; content:"ssm."; startswith; content:".amazonaws.com"; endswith; nocase; flow: to_server; sid:202308311;)
JA3 hash
This rule allows outbound access using a specific JA3 hash
pass tls $HOME_NET any -> $EXTERNAL_NET any (msg:"Only allow Curl 7.79.1 JA3"; ja3.hash; content:"27e9c7cc45ae47dc50f51400db8a4099"; sid:12820009;)
Outbound requests to checkip.amazonaws.com
These rules only allow outbound requests to the SNI checkip.amazonaws.com (http://checkip.amazonaws.com/) if the server certificate issuer is also Amazon. Requires that your firewall policy uses strict order rule evaluation order.
alert tls $HOME_NET any -> $EXTERNAL_NET 443 (ssl_state:client_hello; tls.sni; content:"checkip.amazonaws.com"; endswith; nocase; xbits:set, allowed_sni_destination_ips, track ip_dst, expire 3600; noalert; sid:238745;)
pass tcp $HOME_NET any -> $EXTERNAL_NET 443 (xbits:isset, allowed_sni_destination_ips, track ip_dst; flow: stateless; sid:89207006;)
pass tls $EXTERNAL_NET 443 -> $HOME_NET any (tls.cert_issuer; content:"Amazon"; msg:"Pass rules do not alert"; xbits:isset, allowed_sni_destination_ips, track ip_src; sid:29822;)
reject tls $EXTERNAL_NET 443 -> $HOME_NET any (tls.cert_issuer; content:"="; nocase; msg:"Block all other cert issuers not allowed by sid:29822"; sid:897972;)
Outbound SSH/SFTP servers with AWS_SFTP banner
These rules only allow outbound access to SSH/SFTP servers that have a banner that includes AWS_SFTP, which is the banner for AWS Transfer Family servers. To check for a different banner, replace AWS_SFTP with the banner you want to check for.
pass tcp $HOME_NET any -> $EXTERNAL_NET 22 (flow:stateless; sid:2221382;)
pass ssh $EXTERNAL_NET 22 -> $HOME_NET any (ssh.software; content:"AWS_SFTP"; flow:from_server; sid:217872;)
drop ssh $EXTERNAL_NET 22 -> $HOME_NET any (ssh.software; content:!"@"; pcre:"/[a-z]/i"; msg:"Block unauthorized SFTP/SSH."; flow: from_server; sid:999217872;)
Send DNS query including .amazonaws.com to external DNS servers
This rule allows any DNS query for domain names ending in .amazonaws.com (http://amazonaws.com/) to be sent to external DNS servers.
pass dns $HOME_NET any -> $EXTERNAL_NET any (dns.query; dotprefix; content:".amazonaws.com"; endswith; nocase; msg:"Pass rules do not alert"; sid:118947;)
Stateful rules examples: block traffic
Note
Before using any example rule, test and adapt it to your needs.
The examples in this section contain examples that block specified traffic.
Connections using TLS versions 1.0 or 1.1
This rule blocks connections using TLS version 1.0 or 1.1.
reject tls any any -> any any (msg:"TLS 1.0 or 1.1"; ssl_version:tls1.0,tls1.1; sid:2023070518;)
Multiple CIDR ranges
This rule blocks outbound access to multiple CIDR ranges in a single rule.
drop ip $HOME_NET any-> [10.10.0.0/16,10.11.0.0/16,10.12.0.0/16] (msg:"Block traffic to multiple CIDRs"; sid:278970;)
Multiple SNIs
This rule blocks multiple SNIs with a single rule.
reject tls $HOME_NET any -> $EXTERNAL_NET any (ssl_state:client_hello; tls.sni; pcre:"/(example1\.com|example2\.com)$/i"; flow: to_server; msg:"Domain blocked"; sid:1457;)
Multiple high-risk destination outbound ports
This rule blocks multiple high-risk destination outbound ports in a single rule.
drop ip $HOME_NET any -> $EXTERNAL_NET [1389,53,4444,445,135,139,389,3389] (msg:"Deny List High Risk Destination Ports"; sid:278670;)
Outbound HTTP HOST
This rule blocks outbound HTTP connections that have an IP address in the HTTP HOST header.
reject http $HOME_NET any -> $EXTERNAL_NET any (http.host; content:"."; pcre:"/^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/"; msg:"IP in HTTP HOST Header (direct to IP, likely no DNS resolution first)"; flow:to_server; sid:1239847;)
Outbound TLS with IP in SNI
This rule blocks outbound TLS connections with an IP address in the SNI.
reject tls $HOME_NET any -> $EXTERNAL_NET any (ssl_state:client_hello; tls.sni; content:"."; pcre:"/^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/"; msg:"IP in TLS SNI (direct to IP, likely no DNS resolution first)"; flow:to_server; sid:1239848;)
Any IP protocols other than TCP, UDP, and ICMP
This rule silently blocks any IP protocols other than TCP, UDP, and ICMP.
drop ip any any-> any any (noalert; ip_proto:!TCP; ip_proto:!UDP; ip_proto:!ICMP; sid:21801620;)
SSH non-standard ports
This rule blocks the use of the SSH protocol on non-standard ports.
reject ssh $HOME_NET any -> $EXTERNAL_NET !22 (msg:"Block use of SSH protocol on non-standard port"; flow: to_server; sid:2171010;)
TCP/22 servers non-SSH
This rule blocks the use of TCP/22 servers that aren't using the SSH protocol.
reject tcp $HOME_NET any -> $EXTERNAL_NET 22 (msg:"Block TCP/22 servers that are not SSH protocol"; flow: to_server; app-layer-protocol:!ssh; sid:2171009;)
Stateful rules examples: log traffic
Note
Before using any example rule, test and adapt it to your needs.
The examples in this section demonstrate ways to log traffic. To log traffic, you must configure logging for your firewall. For information about logging Network Firewall traffic, see Logging and monitoring in AWS Network Firewall.
Log traffic direction in default-deny policy
Can be used at the end of a default-deny policy to accurately log the direction of denied traffic. These rules help you to make it clear in the logs who the client is and who the server is in the connection.
reject tcp $HOME_NET any -> $EXTERNAL_NET any (msg:"Default Egress TCP block to server"; flow:to_server; sid:202308171;)
drop udp $HOME_NET any -> $EXTERNAL_NET any (msg:"Default Egress UDP block";sid:202308172;)
drop icmp $HOME_NET any -> $EXTERNAL_NET any (msg:"Default Egress ICMP block";sid:202308177;)
drop tcp $EXTERNAL_NET any -> $HOME_NET any (msg:"Default Ingress block to server"; flow:to_server; sid:20230813;)
drop udp $EXTERNAL_NET any -> $HOME_NET any (msg:"Default Ingress UDP block"; sid:202308174;)
drop icmp $EXTERNAL_NET any -> $HOME_NET any (msg:"Default Ingress ICMP block"; sid:202308179;)
Log traffic to an allowed SNI
The alert keyword can be used in the pass rule to generate alert logs for all matches. This rule logs all passed traffic to an allowed SNI.
pass tls $HOME_NET any -> $EXTERNAL_NET any (ssl_state:client_hello; tls.sni; content:".example.com"; dotprefix; endswith; nocase; alert; sid:202307052;)
Stateful rules examples: rule variables
Note
Before using any example rule, test and adapt it to your needs.
The following JSON defines an example Suricata compatible rule group that uses the variables HTTP_SERVERS and HTTP_PORTS, with the variable definitions provided in the rule group declaration.
{
"RuleVariables": {
    "IPSets": {
        "HTTP_SERVERS": {
            "Definition": [
                "10.0.2.0/24",
                "10.0.1.19"
            ]
        }
    },
    "PortSets": {
        "HTTP_PORTS": {
            "Definition": ["80", "8080"]
        }
    }
},
"RulesSource": {
    "RulesString": "alert tcp $EXTERNAL_NET any -> $HTTP_SERVERS $HTTP_PORTS (msg:\".htpasswd access attempt\"; flow:to_server,established; content:\".htpasswd\"; nocase; sid:210503; rev:1;)"
}
}
The variable EXTERNAL_NET is a Suricata standard variable that represents the traffic destination. For more Suricata-specific information, see the Suricata documentation.
Stateful rules examples: IP set reference
Note
Before using any example rule, test and adapt it to your needs.
To reference a prefix list in your rule group, specify a IP set variable name and associate it with the prefix list's Amazon Resource Name (ARN). Then, specify the variable in one or more of your rules, prefacing the variable with @, such as @IP_Set_Variable. The variable represents the IPv4 prefix list that you are referencing. For more information about using IP set references, see Referencing Amazon VPC prefix lists.
The following example shows a Suricata compatible rule that uses an IP set reference variable @BETA as the source port in RulesString. To use an IP set reference in your rule, you must use an @ in front of the IP set variable name, such as @My_IP_set_variable_name.
{
   "RuleVariables":{
      "IPSets":{
         "HTTP_SERVERS":{
            "Definition":[
               "10.0.2.0/24",
               "10.0.1.19"
            ]
         }
      },
      "PortSets":{
         "HTTP_PORTS":{
            "Definition":[
               "80",
               "8080"
            ]
         }
      }
   },
   "ReferenceSets":{
      "IPSetReferences":{
         "BETA":{
            "ReferenceArn":"arn:aws:ec2:us-east-1:555555555555:prefix-list/pl-1111111111111111111_beta"
         }
      }
   },
   "RulesSource":{
      "RulesString":"drop tcp @BETA any -> any any (sid:1;)"
   }
}
Stateful rules examples: Geographic IP filter
Note
Before using any example rule, test and adapt it to your needs.
For information about Geographic IP filtering in Network Firewall, see Geographic IP filtering in Suricata compatible AWS Network Firewall rule groups.
The following shows an example Suricata rule string that generates an alert for traffic to or from Russia:
alert ip any any -> any any (msg:"Geographic IP is from RU, Russia"; geoip:any,RU; sid:55555555; rev:1;)
The following shows an example standard stateful rule group that drops traffic unless it originates from the United States or the United Kingdom:

{
    "RulesSource": {
      "StatefulRules": [
        {
          "Action": "DROP",
          "Header": {
            "DestinationPort": "ANY",
            "Direction": "FORWARD",
            "Destination": "ANY",
            "Source": "ANY",
            "SourcePort": "ANY",
            "Protocol": "IP"
          },
          "RuleOptions": [
            {
              "Settings": [
                "1"
              ],
              "Keyword": "sid"
            },
            {
              "Settings": [
                "src,!US,UK"
              ],
              "Keyword": "geoip"
            }
          ]
        }
      ]
    },
    "StatefulRuleOptions": {
       "RuleOrder": "STRICT_ORDER"
     }
 }
Stateful rules examples: manage rule evaluation order
Note
Before using any example rule, test and adapt it to your needs.
The examples in this section demonstrate ways to modify evaluation behavior by modifying rule evaluation order in Suricata compatible rules. Network Firewall recommends using strict order so that you can have control over the way your rules are processed for evaulation. For information about managing rule evaluation order, see Managing evaluation order for Suricata compatible rules in AWS Network Firewall.
Allow HTTP traffic to specific domains:
Default action order
drop tcp $HOME_NET any -> $EXTERNAL_NET 80 (msg:"Drop established TCP:80"; flow: from_client,established; sid:172190; priority:5; rev:1;)
pass http $HOME_NET any -> $EXTERNAL_NET 80 (http.host; dotprefix; content:".example.com"; endswith; msg:"Allowed HTTP domain"; priority:10; sid:172191; rev:1;)
pass tcp $HOME_NET any -> $EXTERNAL_NET 22 (msg:"Allow TCP 22"; sid:172192; rev:1;)
drop tcp $HOME_NET any -> $EXTERNAL_NET !80 (msg:"Drop All non-TCP:80";  sid:172193; priority:2; rev:1;)
                            
Strict order
pass http $HOME_NET any -> $EXTERNAL_NET 80 (http.host; dotprefix; content:".example.com"; endswith; msg:"Allowed HTTP domain"; sid:172191; rev:1;)
pass tcp $HOME_NET any -> $EXTERNAL_NET 22 (msg:"Allow TCP 22"; sid:172192; rev:1;)
                            
Allow HTTP traffic to specific domains only:
Default action order
pass http $HOME_NET any -> $EXTERNAL_NET 80 (http.host; dotprefix; content:".example.com"; endswith; msg:"Allowed HTTP domain"; priority:1; sid:102120; rev:1;)
pass http $HOME_NET any -> $EXTERNAL_NET 80 (http.host; dotprefix; content:".mydomain.test"; endswith; msg:"Allowed HTTP domain"; priority:1; sid:102121; rev:1;)
drop http $HOME_NET any -> $EXTERNAL_NET 80 (msg:"Drop HTTP traffic"; priority:1; sid:102122; rev:1;)
Strict order
pass http $HOME_NET any -> $EXTERNAL_NET 80 (http.host; dotprefix; content:".example.com"; endswith; msg:"Allowed HTTP domain"; sid:102120; rev:1;)
pass http $HOME_NET any -> $EXTERNAL_NET 80 (http.host; dotprefix; content:".mydomain.test"; endswith; msg:"Allowed HTTP domain"; sid:102121; rev:1;)
Allow HTTP traffic to specific domains only and deny all other IP traffic:
Default action order
pass http $HOME_NET any -> $EXTERNAL_NET 80 (http.host; dotprefix; content:".example.com"; endswith; msg:"Allowed HTTP domain"; priority:1; sid:892120; rev:1;)
drop tcp $HOME_NET any -> $EXTERNAL_NET 80 (msg:"Drop established non-HTTP to TCP:80"; flow: from_client,established; sid:892191; priority:5; rev:1;)
drop ip $HOME_NET any <> $EXTERNAL_NET any (msg: "Drop non-TCP traffic."; ip_proto:!TCP;sid:892192; rev:1;)
drop tcp $HOME_NET any -> $EXTERNAL_NET !80 (msg:"Drop All non-TCP:80"; sid:892193; priority:2; rev:1;)
Strict order
pass http $HOME_NET any -> $EXTERNAL_NET 80 (http.host; dotprefix; content:".example.com"; endswith; msg:"Allowed HTTP domain"; sid:892120; rev:1;)
pass tcp $HOME_NET any <> $EXTERNAL_NET 80 (flow:not_established; sid:892191; rev:1;)
Stateful rules examples: domain list rules
Note
Before using any example rule, test and adapt it to your needs.
Deny list example JSON, rule group creation, and generated Suricata rules
The following JSON shows an example rule definition for a Network Firewall domain list rule group that specifies a deny list.
{
    "RulesSource": {
        "RulesSourceList": {
            "Targets": [
                "evil.com"
            ],
            "TargetTypes": [
                 "TLS_SNI",
                 "HTTP_HOST"
             ],
             "GeneratedRulesType": "DENYLIST"
        }
    }
}
To use the Network Firewall rule specification, we save the JSON to a local file domainblock.example.json, and then create the rule group in the following CLI command:
aws network-firewall create-rule-group --rule-group-name "RuleGroupName" --type STATEFUL --rule-group file://domainblock.example.json --capacity 1000
The following Suricata rules listing shows the rules that Network Firewall creates for the above deny list specification.
drop tls $HOME_NET any -> $EXTERNAL_NET any (ssl_state:client_hello; tls.sni; content:"evil.com"; startswith; nocase; endswith; msg:"matching TLS denylisted FQDNs"; priority:1; flow:to_server, established; sid:1; rev:1;)
drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; content:"evil.com"; startswith; endswith; msg:"matching HTTP denylisted FQDNs"; priority:1; flow:to_server, established; sid:2; rev:1;)
HTTP allow list example JSON and generated Suricata rules
The following JSON shows an example rule definition for a Network Firewall domain list rule group that specifies an HTTP allow list. The . before the domain name in .amazon.com is the wildcard indicator in Suricata.
{
    "RulesSource": {
        "RulesSourceList": {
            "Targets": [
                ".amazon.com",
                "example.com"
            ],
            "TargetTypes": [
                "HTTP_HOST"
            ],
            "GeneratedRulesType": "ALLOWLIST"
        }
    }
}
The following Suricata rules listing shows the rules that Network Firewall creates for the above allow list specification.
pass http $HOME_NET any -> $EXTERNAL_NET any (http.host; dotprefix; content:".amazon.com"; endswith; msg:"matching HTTP allowlisted FQDNs"; priority:1; flow:to_server, established; sid:1; rev:1;)
pass http $HOME_NET any -> $EXTERNAL_NET any (http.host; content:"example.com"; startswith; endswith; msg:"matching HTTP allowlisted FQDNs"; priority:1; flow:to_server, established; sid:2; rev:1;)
drop http $HOME_NET any -> $EXTERNAL_NET any (http.header_names; content:"|0d 0a|"; startswith; msg:"not matching any HTTP allowlisted FQDNs"; priority:1; flow:to_server, established; sid:3; rev:1;)
TLS allow list example JSON and generated Suricata rules
The following JSON shows an example rule definition for a Network Firewall domain list rule group that specifies a TLS allow list.
{
    "RulesSource": {
        "RulesSourceList": {
            "Targets": [
                ".amazon.com",
                "example.com"
            ],
            "TargetTypes": [
                "TLS_SNI"
            ],
            "GeneratedRulesType": "ALLOWLIST"
        }
    }
}
The following Suricata rules listing shows the rules that Network Firewall creates for the above allow list specification.
pass tls $HOME_NET any -> $EXTERNAL_NET any (ssl_state:client_hello; tls.sni; dotprefix; content:".amazon.com"; nocase; endswith; msg:"matching TLS allowlisted FQDNs"; priority:1; flow:to_server, established; sid:1; rev:1;)
pass tls $HOME_NET any -> $EXTERNAL_NET any (ssl_state:client_hello; tls.sni; content:"example.com"; startswith; nocase; endswith; msg:"matching TLS allowlisted FQDNs"; priority:1; flow:to_server, established; sid:2; rev:1;)
drop tls $HOME_NET any -> $EXTERNAL_NET any (msg:"not matching any TLS allowlisted FQDNs"; priority:1; ssl_state:client_hello; flow:to_server, established; sid:3; rev:1;)
Block traffic from $EXTERNAL_NET to $HOME_NET, allow outbound domain filtering
These rules block all unsolicited traffic from $EXTERNAL_NET to $HOME_NET while still allowing outbound domain filtering.
reject tls any any -> any any (msg:"Vulnerable versions of TLS"; ssl_version:tls1.0,tls1.1; sid:2023070518;)
Stateful rules examples: standard stateful rule groups
The following JSON shows an example rule definition for a Network Firewall basic stateful rule group.
{
    "RulesSource": {
        "StatefulRules": [
          {
            "Action": "DROP",
            "Header": {
                "Protocol": "HTTP",
                "Source": "$HOME_NET",
                "SourcePort": "ANY",
                "Direction": "ANY",
                "Destination": "$EXTERNAL_NET",
                "DestinationPort": "ANY"
            },
            "RuleOptions": [ {
                    "Keyword": "msg",
                    "Settings": [ "\"this is a stateful drop rule\""
                    ]
                },
                {
                    "Keyword": "sid",
                    "Settings": [ "1234"
                    ]
                }
            ]
        }
      ]
    }
}
The following Suricata rules listing shows the rules that Network Firewall generates for the above deny list specification.
drop http $HOME_NET ANY <> $EXTERNAL_NET ANY (msg:this is a stateful drop rule; sid:1234;)


