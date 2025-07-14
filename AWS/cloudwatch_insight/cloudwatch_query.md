# Cloudwatch Insight Query 

## DNS Query 
```bash
# Filter Query where NOERROR (successfull resolutoin) and not "NXDOMAIN" (domain does not exist) 
fields @timestamp, srcaddr, query_name, rcode
| filter rcode != "NOERROR" and rcode != "NXDOMAIN"
| sort @timestamp desc
| limit 100

1. General Query for All Firewall-Blocked Queries

fields @timestamp, query_name, srcaddr, srcids.instance, firewall_rule_action, firewall_rule_group_id, firewall_domain_list_id, rcode, query_type, srcport, transport
| filter firewall_rule_action = "BLOCK"
| sort @timestamp desc
| limit 100

2. Blocked Queries from a Specific Source IP Address (srcaddr)

fields @timestamp, query_name, srcaddr, srcids.instance, firewall_rule_action, firewall_rule_group_id, firewall_domain_list_id, rcode, query_type, srcport, transport
| filter firewall_rule_action = "BLOCK" and srcaddr = "YOUR_SOURCE_IP_ADDRESS"
| sort @timestamp desc
| limit 100

3. Blocked Queries for a Specific Domain Name (query_name)

fields @timestamp, query_name, srcaddr, srcids.instance, firewall_rule_action, firewall_rule_group_id, firewall_domain_list_id, rcode, query_type, srcport, transport
| filter firewall_rule_action = "BLOCK" and query_name = "YOUR_DOMAIN_NAME"
| sort @timestamp desc
| limit 100

4. Blocked Queries by a Specific Firewall Rule Group or Domain List

fields @timestamp, query_name, srcaddr, srcids.instance, firewall_rule_action, firewall_rule_group_id, firewall_domain_list_id, rcode, query_type, srcport, transport
| filter firewall_rule_action = "BLOCK" and firewall_rule_group_id = "YOUR_RULE_GROUP_ID"
| sort @timestamp desc
| limit 100

fields @timestamp, query_name, srcaddr, srcids.instance, firewall_rule_action, firewall_rule_group_id, firewall_domain_list_id, rcode, query_type, srcport, transport
| filter firewall_rule_action = "BLOCK" and firewall_domain_list_id = "YOUR_DOMAIN_LIST_ID"
| sort @timestamp desc
| limit 100

# 5. Queries with SERVFAIL Response Code (General DNS Failures)

fields @timestamp, query_name, srcaddr, srcids.instance, rcode, firewall_rule_action, firewall_rule_group_id, firewall_domain_list_id, query_type, srcport, transport
| filter rcode = "SERVFAIL"
| sort @timestamp desc
| limit 100

fields @timestamp, srcaddr, query_name,query_type, rcode
| filter rcode != "NOERROR" and rcode != "NXDOMAIN"
| sort @timestamp desc
| limit 100
```
