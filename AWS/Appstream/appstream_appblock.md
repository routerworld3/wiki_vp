---
title: "Appstream AppBlock"
---

## Summary

This document provides a detailed instruction set for using Terraform and CloudFormation to deploy AWS AppStream AppBlocks, along with any special steps required for specific application installations.

AppStream AppBlock is a mechanism that captures an application's installation process using an AppBlock Builder session. The result is a virtual hard disk (VHD) stored in an S3 bucket. This VHD is then mounted at runtime by AppStream Fleets, enabling application delivery to users without exposing the underlying OS.

Both **Terraform** and **CloudFormation** are used to provision resources:

- Terraform creates and manages AppBlocks, Applications, Builders, and associations.
- CloudFormation handles creation of Elastic Fleets.

## Pull Request Process

A full AppBlock deployment can be initiated through a single pull request. However, due to the multi-stage dependency between AppStream resources, **the pipeline must be run twice**:

### Why Two Pipeline Runs Are Required

1. **First Run**: Provisions foundational AppStream resources such as the AppBlock, AppBlock Builder, Application, and IAM roles. At this point, the AppBlock is in an **Inactive** state because no VHD exists yet—only a reference to an S3 bucket is set.
2. **Manual Recording Phase**: The admin launches the AppBlock Builder session to perform installation and recording. Upon completion, the VHD is generated and stored in S3.
3. **Second Run**: After the recording is complete and the VHD is available, the pipeline is run again to apply final configuration (e.g., SSM parameter updates, application associations) and complete resource dependencies.

This two-run process ensures that the final AppBlock and Application configuration is valid, executable, and ready to be consumed by AppStream Fleets.

![Appblock Flow Diagram](/docs/KB/images/appblock_flow.png)
### 🧩 **AppStream AppBlock Deployment Flow (ASCII Diagram)**

```text
                              ┌──────────────┐
                              │ 1st Pipeline │
                              │     Run      │
                              └──────┬───────┘
                                     │
                                     ▼
      ┌────────────────┐      ┌────────────────────┐      ┌─────────────┐
      │ AppBlock       │◄─────┤ AppBlock Builder    ├─────┤ Builder VPC │
      └─────┬──────────┘      └────────────────────┘      └─────────────┘
            │
      (AppBlock inactive)
            │
       ┌────▼────┐
       │ 1.1     │ Launch Builder Session
       └────┬────┘
            ▼
       ┌────▼────┐
       │ 1.2     │ Install App in Builder
       └────┬────┘
            ▼
       ┌────▼────┐
       │ 1.3     │ Stop Recording & Save VHD
       └────┬────┘
            ▼
       ┌────▼────┐
       │   S3    │ ←─── VHD Stored
       └────┬────┘
            ▼
       ┌────▼────┐
       │ 1.4     │ Update SSM Param with EXE Path
       └────┬────┘
            ▼
       ┌──────────────┐
       │ 2nd Pipeline │
       │     Run      │
       └──────┬───────┘
              ▼
       ┌────────────────┐
       │ Application     │
       │ (exe path, logo)│
       └──────┬──────────┘
              │
              ▼
       ┌────────────────┐
       │ CloudFormation │
       └──────┬──────────┘
              ▼
      ┌────────────────────┐
      │ Elastic Fleet      │
      │  (stream.std.med)  │
      └──────┬─────────────┘
             ▼
        ┌──────────────┐
        │    Stack     │
        └──────────────┘

```

### Process Flow

**Initial Pipeline Execution:**

- Terraform creates foundational resources such as the AppBlock, AppBlock Builder, IAM roles, and the AppStream Application.
- A CloudFormation stack provisions the Elastic Fleet.
- The AppBlock will be in an **Inactive** state initially because it references only an S3 bucket—not a finalized VHD.

**Manual Steps for Finalization:**

1. **Launch the AppBlock Builder session**
   - Use the AWS Console to activate the AppBlock Builder.
   - This launches a session where the admin can record the application installation.

2. **Install the Application**
   - Upload the application installer via drag-and-drop to the Builder session (e.g., Temporary Files directory).
   - Start the recording process.
   - Begin installation. If prompted, install the app for **All Users**, not just the current user.
   - Follow any application-specific setup steps (see below).

3. **Complete the Recording**
   - Stop the recording once installation and configuration are complete.
   - Confirm the correct launch path for the application's executable.
   - Finalizing the session will generate the VHD and store it in the specified S3 bucket.

4. **Post-Installation Configuration**
   - Update the associated SSM Parameter Store entry with the verified launch path.
   - Re-run the CodePipeline to deploy dependent resources.

5. **Fleet Activation**
   - Elastic Fleets are created using CloudFormation and begin in a **Stopped** state.
   - Admin must manually start the Fleet in each environment where the AppBlock is required.

## Resource Overview

### Terraform Resources

```
┌──────────────────────────────────────────────────────────────────────┐
│                aws_appstream_app_block_builder                       │
│  - name                        → Unique name for builder              │
│  - instance_type              → EC2 type used to build app           │
│  - platform                   → e.g., WINDOWS_SERVER_2019            │
│  - iam_role_arn               → Role for script access               │
│  - enable_default_internet_access → true/false                       │
└──────────────────────────────────────────────────────────────────────┘
                                   │
       (Association: aws_appstream_app_block_builder_app_block_association)
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                   aws_appstream_app_block                            │
│  - name                        → App block name                      │
│  - source_s3_location          → S3 bucket & key for app zip         │
│  - setup_script_details        → Script path, S3 location, timeout   │
│  - packaging_type              → CUSTOM (required)                   │
└──────────────────────────────────────────────────────────────────────┘
                                   │
                     (Referenced by: aws_appstream_application)
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                   aws_appstream_application                          │
│  - name                        → Application name                    │
│  - app_block_arn               → Reference to AppBlock ARN           │
│  - launch_path                 → .exe or script path to start app    │
│  - working_directory           → App launch directory (optional)     │
│  - launch_parameters           → Any command-line params             │
└──────────────────────────────────────────────────────────────────────┘
                                   │
          (Association: aws_appstream_application_fleet_association)
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                aws_appstream_application_fleet_association           │
│  - application_name            → Link to above application           │
│  - fleet_name                  → Name of AppStream fleet             │
└──────────────────────────────────────────────────────────────────────┘
```

### CloudFormation Stack for Elastic Fleet

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: CloudFormation template to create an AppStream 2.0 shared AppBlock Builder for specific AppBlocks and Applications.

Resources:
  ElasticFleet:
    Type: AWS::AppStream::Fleet
    Properties:
      Name: ${name}
      InstanceType: stream.standard.medium
      FleetType: ELASTIC
      MaxConcurrentSessions: ${max_sessions}
      Platform: WINDOWS_SERVER_2019
      VpcConfig:
        SubnetIds:
          - ${services_aza}
          - ${services_azb}
        SecurityGroupIds:
          - ${security_group_id}
      MaxUserDurationInSeconds: 7200
      DisconnectTimeoutInSeconds: 900
      Description: AppStream elastic fleet for nnpi
      EnableDefaultInternetAccess: false
```

## Application-Specific Installation Instructions

### DBeaver (for use with Oracle)

1. While the AppBlock recording is active:
   - Launch DBeaver and create an Oracle connection (do not save password).
   - Go to `Window > Preferences > Connections` and uncheck **Use Windows trust store**.
   - Restart DBeaver.
   - Attempt a connection to trigger driver installation prompt.
   - Accept prompt, then decline login.
   - Close DBeaver.
2. End the recording.

### SQLPlus

1. Upload the full Oracle Client installer ZIP to the Builder session.
2. Extract to `C:\` to avoid path length issues.
3. Begin recording, run the installer:
   - Select **Custom** installation.
   - Use **built-in Windows account**.
   - Choose default install path.
   - Select only **SQL*Plus** component.
4. Once installed:
   - Open PowerShell and run `sqlplus`. If not found:
     - Open **Environment Variables**, edit `Path` under **System Variables**.
     - Add: `C:\app\client\AppBlockBuilderAdmin\product\19.0.0\client_1\bin`
5. End recording and complete AppBlock finalization.

