Resources : 
https://github.com/aws-samples/amazon-cloudwatch-log-centralizer

https://aws.amazon.com/blogs/architecture/stream-amazon-cloudwatch-logs-to-a-centralized-account-for-audit-and-analysis/

 **Lambda Code To Trigger Cloudwatch Log Subscription Filter**
```ptyhon
#Lambda.py
# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import boto3
from CentralLogging import CentralLogging

# Lambda handler triggered by a CloudWatch Event whenever a new log group is created.  Calls the core code to add new subscription to the newly created log group


def lambda_handler(event, context):
    central_logger = CentralLogging()
    print(event)
    print("In add_new_subscription Lambda - requestParameters: ")

    # Retrieves the request parameters from the event that was called to create the log group
    request_parameters = event['detail']['requestParameters']
    print(request_parameters)

    # Extract the log group name from the request parameters to create the log group
    if request_parameters:
        print("     Inspecting request parameters for log_group_name:")
        log_group_name = request_parameters['logGroupName']
        print(log_group_name)

        # Call code to add the subscription to the log group
        central_logger.add_subscription_filter(log_group_name)
```
**Centralied Logging**

```python
#CentralLogging.py

# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import boto3


class CentralLogging:
    def __init__(self):
        self.log_client = boto3.client('logs')
        self.ssm_client = boto3.client('ssm')
        print('Central Logger Made')

    def add_subscriptions_to_existing_log_groups(self):

        # Retrieve all of the existing log groups
        log_group_response = self.log_client.describe_log_groups()

        # Loop over multiple calls to describe_log_groups() as necessary using the next token
        while True:
            # If there are log groups, iterate over each one, retrieve its name, and call code to add the subscription to it
            if log_group_response:

                for log_group in log_group_response['logGroups']:
                    log_group_name = log_group['logGroupName']
                    self.add_subscription_filter(log_group_name)

                if 'nextToken' in log_group_response:
                    log_groups_next_token = log_group_response['nextToken']

                    if log_groups_next_token:
                        log_group_response = self.log_client.describe_log_groups(nextToken=log_groups_next_token)
                    else:
                        break

                else:
                    break

    # Add subscription to centralized logging to the log group with log_group_name
    def add_subscription_filter(self, log_group_name):
        # Retrieve the destination for the subscription from the Parameter Store
        destination_response = self.ssm_client.get_parameter(Name='LogDestination')

        # Error if no destination, otherwise extract destination id from response
        if not destination_response:
            raise ValueError(
                'Cannot locate central logging destination, put_subscription_filter failed')
        else:
            destination = destination_response['Parameter']['Value']

        # Error to try to add subscription if one already exists, so delete any existing subscription from this log group
        self.delete_existing_subscription_filter(log_group_name)

        # Put the new subscription with the destination onto the log group
        self.log_client.put_subscription_filter(
            logGroupName=log_group_name,
            filterName='Destination',
            filterPattern='',
            destinationArn=destination
        )

    # Delete an existing subscription from the log group
    def delete_existing_subscription_filter(self, log_group_name):
        # Retrieve any existing subscription filters (only can be one)
        subscription_filters = self.log_client.describe_subscription_filters(
            logGroupName=log_group_name)

        # Iterate over results if there are any (again, should not be multiple, but to follow the convention of the SDK)
        for subscription_filter in subscription_filters['subscriptionFilters']:
            # Retrieve the subscription filter name to use in the call to delete
            filter_name = subscription_filter['filterName']

            # Delete any subscriptions that are found on the log group
            self.log_client.delete_subscription_filter(
                logGroupName=log_group_name,
                filterName=filter_name
            )
```

**Updated Logic with CW Log Group Nameing Compliance**
```python
import boto3
import re

# ----------------------------
# Centralizedlogging.py
# CentralLogging class handles log subscription logic
# ----------------------------
class CentralLogging:
    def __init__(self):
        self.log_client = boto3.client('logs')
        self.ssm_client = boto3.client('ssm')
        print('Central Logger Initialized')

    def add_subscription_filter(self, log_group_name):
        # Enforce naming format: /aws/service/resource_id/type_of_log
        pattern = r'^/aws/[^/]+/[^/]+/[^/]+$'
        if not re.match(pattern, log_group_name):
            print(f"[WARNING] Skipping '{log_group_name}' - does not match required format.")
            # Optional: Uncomment to attach fallback destination
            # self.add_fallback_subscription(log_group_name)
            return

        # Get destination ARN from SSM Parameter Store
        try:
            destination_response = self.ssm_client.get_parameter(Name='LogDestination')
            destination_arn = destination_response['Parameter']['Value']
        except Exception as e:
            print(f"[ERROR] Failed to retrieve 'LogDestination' from SSM: {e}")
            return

        # Remove any existing subscription filters
        self.delete_existing_subscription_filter(log_group_name)

        # Add new subscription filter
        try:
            self.log_client.put_subscription_filter(
                logGroupName=log_group_name,
                filterName='Destination',
                filterPattern='',
                destinationArn=destination_arn
            )
            print(f"[INFO] Subscription filter added to: {log_group_name}")
        except Exception as e:
            print(f"[ERROR] Failed to add subscription filter to '{log_group_name}': {e}")

    def delete_existing_subscription_filter(self, log_group_name):
        try:
            response = self.log_client.describe_subscription_filters(logGroupName=log_group_name)
            for sub in response.get('subscriptionFilters', []):
                filter_name = sub['filterName']
                self.log_client.delete_subscription_filter(
                    logGroupName=log_group_name,
                    filterName=filter_name
                )
                print(f"[INFO] Deleted existing subscription: {filter_name} from {log_group_name}")
        except Exception as e:
            print(f"[ERROR] Error deleting subscription filter from '{log_group_name}': {e}")

    # Optional fallback subscription if log group format is incorrect
    def add_fallback_subscription(self, log_group_name):
        try:
            fallback_response = self.ssm_client.get_parameter(Name='FallbackLogDestination')
            fallback_arn = fallback_response['Parameter']['Value']

            self.delete_existing_subscription_filter(log_group_name)

            self.log_client.put_subscription_filter(
                logGroupName=log_group_name,
                filterName='FallbackDestination',
                filterPattern='',
                destinationArn=fallback_arn
            )
            print(f"[INFO] Fallback subscription added to: {log_group_name}")
        except Exception as e:
            print(f"[ERROR] Failed to attach fallback subscription to '{log_group_name}': {e}")

```
**Updted Lambda Code**
```python
# ----------------------------
##Lambda.py
# Lambda handler triggered by EventBridge (CloudTrail CreateLogGroup event)
# ----------------------------
def lambda_handler(event, context):
    print("==== Lambda Triggered ====")
    print(event)

    central_logger = CentralLogging()

    try:
        request_parameters = event['detail']['requestParameters']
        log_group_name = request_parameters['logGroupName']
        print(f"[INFO] New log group created: {log_group_name}")

        central_logger.add_subscription_filter(log_group_name)

    except KeyError as e:
        print(f"[ERROR] Missing expected field in event: {e}")
    except Exception as e:
        print(f"[ERROR] Unexpected error occurred: {e}")
```
