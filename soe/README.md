## Project Overview
This is a simple Terraform project which will deploy some resources to a subscription in my Azure tenant. It will first deploy two Resource Groups, one Production and one Development. Within both of these Resource Groups, a VM and two Storage Accounts will be created. One storage account is the primary, and the other one will contain log files.

The VM and primary storage account will be in one subnet, and the log account on a separate subnet.

The purpose of using Terraform to deploy these resources is to deploy resources according to a minimum security baseline. The Terraform configuration will enforce a number of controls, e.g. encryption, blob versioning automatically. Within the 'outputs.tf' file, there are also preconditions on the key outputs which will prevent the creation of resources that do not conform to the requirements.

Additionally, the Terraform deployment will be backed by policies defined in Azure Policy. Where possible, these policies will deny the creation of a non-compliant resource. If this is not possible, non-compliant resources will be audited.

This is a basic Terraform project which will be iteratively improved as I learn more about Terraform. The overall purpose is to learn how Terraform and IaC can be used to automate compliance, as well as provide audit evidence.

### How this ties into GRC
There are a few problems with GRC at the moment. Firstly, it relies on spreadsheets, questionnaires and interpreting policy documentation. Secondly, just because a policy states 'All storage accounts must be encrypted' doesn't mean this is actually being done. Thirdly, auditing and review processes are manual, and look at evidence from the past. A control may have been effective 5 months ago, but what about now? Screenshots with timestamps only go so far, and they take time to collect.

Infrastructure as Code (IaC) provides a way to deploy infrastructure with controls baked in, and backed by additional mechanisms such as preconditions and Azure Policy - this can instantly deny creation of insecure resources (the dreaded public S3 bucket), or instantly audit such events and alert the relevant teams so such events are detected in a timely manner. 

Also, using software development principles such as version control, policy definitions and infrastructure configurations can be stored in a repository such as GitHub and used as evidence that policies or configurations have been in place and have not changed without going through due process.

This first project will focus on the secure deployment part.

#### Controls Implemented
For ease, I will only be referencing NIST CSF v2.0 control sets in this project. There are plenty of resources out there that can be used to map controls to other standards or frameworks, and given that the controls I will implement are fairly basic they can be easily mapped.

**AC-3 (Access Enforcement)**: Enforce approved authorisations for logical access to information and system resources in accordance with applicable access control policies. 

'public_network_access_enabled = false' satisfies this control. This control could be further improved by setting up rules to only allow access from specific subnets, or requiring a key, for example.

**SC-28 (Protection of Information at Rest)**: Protect the confidentiality of information at rest.

'infrastructure_encryption_enabled = true' satisfies this control. Technically, Storage Accounts are encrypted by default, however infrastructure encryption provides a double layer of encryption.

**AU-3 (Content of Audit Records)**: Ensure that audit records contain information that establishes the following:
- What type of event occurred;
- When the event occurred;
- Where the event occurred;
- Source of the event;
- Outcome of the event; and
- The identity of any individuals, subject, or objects/entities associated with the event.

Setting up an Azure Monitor Diagnostic Setting satisfies this control. Strong logging/auditing controls enables thorough and more timely investigation of security incidents. Addresses threats related to non-repudiation as events can be tied back to an identity, source and location.

**AU-9 (Protection of Audit Information)**: Protect audit information and audit logging tools from unauthorized access, modification, and deletion; and
Alert [Assignment: organization-defined personnel or roles] upon detection of unauthorized access, modification, or deletion of audit information.

Configuring the logging account's storage container to have an immutability policy satisfies this control. Additionally, the container is private, therefore cannot be accessed from public networks. This control prevents tampering with audit logs to hide potential malicious activity.

**Data Sovereignty**: Additionally, there is a requirement that all resources deployed to the resource group must be deployed to Australia. This is a likely scenario for an organisation which may have data sovereignty requirements. Having this requirement prevents resources within this resource group from ever being created outside of this data sovereignty zone.