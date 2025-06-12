Resources : 
https://github.com/aws-samples/amazon-cloudwatch-log-centralizer
https://aws.amazon.com/blogs/architecture/stream-amazon-cloudwatch-logs-to-a-centralized-account-for-audit-and-analysis/

# Lambda Code To Trigger Cloudwatch Log Subscription Filter 
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
# Centralied Logging 

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
```python
