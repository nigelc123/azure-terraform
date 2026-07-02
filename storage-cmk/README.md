# Creating a Storage Account with a Customer Managed Key
By default, Microsoft encrypts Azure Storage accounts with a key under their control (Microsoft-Managed Keys). However, some frameworks/standards require or recommend the organisation to be in control of their own keys - e.g.:
- PCI DSS v4.0 (Req 3.6-3.7): Documented key-management procedures covering the full key lifecycle; for manual cleartext key operations, split knowledge and dual control are required so no single person can reconstruct a key; Key custodians must formally acknowledge their responsibilities; unauthorised key substitution must be prevented.
- CSA Cloud Controls Matrix CEK (Cryptography, Encryption & Key Management) domain requires CSPs to provide the capability for users to manage their own keys.
- HIPAA requires strict key management, including key generation, storage, distribution and rotation.

This can be implemented using a Storage Account that utilises a Customer Managed Key (CMK) to encrypt the account.

Using a CMK, you can also choose to automatically update the key version used for encryption whenever a new version is available in the Key Vault.

![Azure Storage w CMK](./assets/screenshots/Azure%20Storage%20w%20CMK.png)
# How it Works
Your storage account is first encrypted with an Account Encryption Key (AEK), which is an AES-256 key uniquely generated per storage account. This AEK is then encrypted or **wrapped** using your CMK which is stored in Azure Key Vault. 

When you read a file, Azure uses the UnwrapKey function on the Key Vault which decrypts the AEK. Once the AEK is decrypted, this can then be used to decrypt the account.
- This means that if the CMK is deleted, expires or is disabled the AEK cannot be decrypted and therefore the data in the account becomes inaccessible.
# Requirements
1. An Azure Key Vault.
2. Key Vault Administrator RBAC permissions on the Key Vault.
3. A Managed Identity for the Storage Account (this is used in Step 3 of the above diagram for the Storage Account to authenticate to Key Vault).
4. A Storage Account
## Notes
- Enable RBAC Authorisation on the Key Vault in order to assign granular permissions using Azure RBAC. This will be required for assigning Key Vault Administrator, and the appropriate permissions for the Managed Identity.
- Azure requires **Soft Delete** and **Purge Protection** to be on when using the generated encryption keys for Storage accounts. This is to prevent irreversible data loss from an accidental deletion of a CMK.
- Use an asymmetric algorithm for the CMK — this means that the public key is used to wrap (encrypt) the AEK, and the private key is used to unwrap (decrypt).
- The Managed Identity needs the correct permissions in order to actually use the Key Vault. It will need the Key Vault Crypto Service Encryption User role. 
### Soft Delete
Soft delete is used to prevent accidental deletion of a key vault and its contents. It is essentially like a recycle bin, where a deleted object remains recoverable for a user-configurable retention period (or default 90 days). In the lab, I have configured soft delete retention for 7 days to allow for faster cleanup.

Soft delete is enabled by default when you create a new key vault. It cannot be disabled.
### Purge Protection
Purge protection is used to prevent intentional deletion of a key vault and its contents by an attacker or malicious insider. It is basically a recyle bin with a time-based lock. Deleted items can be recovered at any point within the configuratble retention period.

**There is no account privilege (even Microsoft) that can permanently delete or purge a key vault until the retention period has elapsed.** Once the retention period has elapsed, the key vault object is automatically purged.

Azure Policy provides a built-in policy which you could use to require storage accounts to use CMKs, if you want to either deny creation of storage accounts without CMKs or audit the activity to detect drift from the requirement.

Microsoft Learn [link](https://learn.microsoft.com/en-us/azure/storage/common/customer-managed-keys-configure-new-account?toc=%2Fazure%2Fstorage%2Fblobs%2Ftoc.json&bc=%2Fazure%2Fstorage%2Fblobs%2Fbreadcrumb%2Ftoc.json&tabs=azure-cli).

# GUI Creation Walkthrough
*This assumes that you have already created a Resource Group for the Storage Account to live in.*
## 1. Creation of the Key Vault
**IMPORTANT NOTE:** In Production, ALWAYS have purge protection on.

First, we need to create the Key Vault. Soft-delete is enabled by default, with a default value of 90 days. I can delete the key vault, however it will remain soft-deleted for 90 days.

*Note 2:* I have allowed public access to the account, however restricted it to my laptop's public IP address. This is fine for testing purposes - otherwise I would not be able to actually perform any actions on the key vault from my client laptop.
![Key Vault Creation](./assets/screenshots/Key%20Vault%20Creation.png)

*Edit after-the-fact:* *As mentioned above, purge protection is required to be on for use with Azure Storage Accounts.*

In order to create and manage keys, I need to assign myself the Key Vault Administrator role.
![Key Vault Admin Assignment](assets/screenshots/Key%20Vault%20Admin%20assignment.png)

## 2. Key Generation
Next, we need to generate the encryption key. I have selected an RSA key with a key length of 4096 bits as a best practice. 

**IMPORTANT NOTE:** In production, you will likely want to set expiration dates and key rotation policies, so the key automatically expires and/or rotates after a configured amount of time. Since this is a lab environment, I have not configured any of these.

![Key Generation](./assets/screenshots/Key%20Generation.png)

## 3. Managed Identity Creation
Next, we need to create the User-Assigned Managed Identity for the Storage Account to use to authenticate to Key Vault. A Managed Identity allows for secure authentication without ever having to handle credentials ourselves. Therefore there are no credentials to store, that can be intercepted by malicious actors.

Why User-Assigned? This is because the Storage Account doesn't yet exist, so we cannot create a System-Assigned Managed Identity as this type of Identity is coupled to the resource. Additionally, the identity needs to have the correct Key Vault permissions **before** the storage account is created, which is not possible with a System-Assigned Managed Identity.

*Note:* Make sure that the region you deploy to matches that of the Resource Group.

![Managed Identity Creation](./assets/screenshots/Managed%20Identity%20Creation.png)

## 4. Managed Identity RBAC Assignment
The Managed Identity requires the right permissions in order to actually be able to perform the operations we need on the keys, otherwise it is useless. The role that allows this is *Key Vault Crypto Service Encryption User*. 

As per the description, it allows reading the metadata of keys, and wrap/unwrap (encrypt/decrypt the AEK) operations. This is the permission that allows the CMK to decrypt and encrypt the storage account key.

![Managed Identity Role Assignment](./assets/screenshots/Managed%20Identity%20Role%20Assignment.png)

## 5. Create a Storage Account
Now, we create the Storage account. I have skipped over the previous screens, as the main focus of the lab is setting up encryption. Select Customer-Managed Keys (CMK), and select the Azure Key Vault and key we have created in the previous steps. Then, select the managed identity that we have created.

*Note:* Azure encrypts data at rest by default. Enabling infrastructure encryption adds a second layer of encryption. Infrastructure encryption encrypts with two different encryption algorithms and two different keys.
![Storage Account Creation Encryption Settings](./assets/screenshots/Storage%20Account%20Creation%20w%20encryption%20settings.png)

## 6. Test Encryption
I have now created a test container and uploaded a test file called file.txt, which just contains the text "This file is a super secret encrypted file.".

Notice if you look at the blob properties, SERVER ENCRYPTED is 'true', meaning that the file is encrypted. When you download the file, the backend uses the encryption key to perform the unwrap operation, allowing the file to be decrypted.

![Encryption Properties](./assets/screenshots/Blob%20encryption%20properties.png)

## 7. Disable the Key
To ensure that the encryption key is working as intended, we will now disable the key. This should mean that the file is inaccessible, as there is no key to perform decryption on the AEK.

![Disabling Key](./assets/screenshots/Disable%20Key.png)

And as we see below, when we attempt to access the file we get an error. The details of the error show 'The key vault key is not found to unwrap the encryption key.' as expected.
![Key Disabling Error](./assets/screenshots/Error%20when%20disabling%20key.png)

This demonstrates the importance of having purge protection and soft delete. In this case, we have only disabled the key so we can re-enable it. If purge protection and soft delete were not on and the key were intentionally or accidentally deleted, we would no longer have access to our data.

## 8. Audit Logging
It is also important to have robust audit logging configured, and this is a compliance requirement. We need to be able to see who attempted to, or successfully performed certain operations, such as UnwrapKey, WrapKey, Encrypt etc, when the event occurred, the source of the event etc.

This satisfies CSA LOG-10: Encryption Monitoring and Reporting.

## 8a. Create a Log Analytics Workspace
**IMPORTANT NOTE:** Log Analytics charges pay-as-you-go by default, based on the amount of data you ingest, per GB. I have set a limit to 1 GB per day, just because I am paranoid.

First create a Log Analytics Workspace. This will then be pointed to by the Key Vault's monitoring that we will set up in the next step.
![Creating Log Analytics Workspace](./assets/screenshots/Creating%20Log%20Analytics%20Workspace.png)

## 8b. Create a Diagnostic Setting for the Key Vault
Under the Key Vault, go to Monitoring -> Diagnostic settings -> Add diagnostic setting. Configure the logs to send to the Log Analytics workspace we created earlier.![Creating a Diagnostic Setting](./assets/screenshots/Key%20Vault%20Diagnostic%20Setting.png)

*Note:* Events will only be collected **after** the creation of the monitoring settings. Perform some operations to show what they look like.

Below is an example of what logs look like, as well as a snippet of a detailed log entry.
![Key Vault Log example](./assets/screenshots/Key%20Vault%20Logs.png)

Below I run a more useful query which focuses more on some key details we may want to focus on, such as the operation name (e.g. KeyUnwrap, Authentication, KeyGet), the result of the operation (successful/failure), the caller IP address and the resource we are querying against.

![Detailed Log example](./assets/screenshots/Detailed%20Log.png)

# Recreating the lab in Terraform
Creating this in the GUI is good to get a picture for how the resources work together, the sequencing and where to look - however I am on a Terraform learning journey, so lets create this in Terraform as well. Refer to the [Terraform](main.tf) code blocks for what this looks like. 

I have omitted the creation of the Diagnostic Setting and Log Analytics Workspace for this, as I wanted the focus to be on the infrastructure itself.

# Known Issues & Lessons Learned
When attempting to recreate the lab in Terraform, I encountered a few issues - mostly related to sequencing of resource creation, RBAC propagation and defining dependencies.

## RBAC Propagation
According to Azure documentation, RBAC can take a couple of minutes to properly propagate. To avoid any issues with propagation, I learned that Terraform has a time_sleep provider which can be used to halt - in this case - until RBAC has propagated. See line 83 of main.tf where I have defined a time_sleep.wait_for_rbac which will wait for 2 minutes after the creation of the Service Principal Key Vault Administrator role.

## 403 Error: Checking for presence of existing Key "insert-key-name" (Key Vault "insert-key-vault-url"): unexpected status 403 (403 Forbidden) with error: Forbidden: Caller is not authorized to perform action on resource.
When first deploying this, I was getting this error. After digging, I realised that the error was occuring because:
1. The Key Vault has enable_rbac_authorization = true on, meaning permissions are determined by RBAC only.
2. I had not assigned any RBAC role to the Service Principal running Terraform. The Service Principal did not have *any* role assignment on the Key Vault which would allow it to administer the Key Vault, because the creator of a Key Vault doesn't implicitly gain administrative rights over it.


### To fix:
I first tried using Terraform to assign the role "Key Vault Administrator" to the Service Principal itself (refer to Line 70 of main.tf). This initially worked, as it turns out I was performing all of the actions using my interactive 'az login' session (hence the data blocks were using the current config based on my az login session which is the Global Administrator).

However, when I fixed up the authentication such that the Service Principal was actually the one performing the actions this no longer worked. Again, this was due to RBAC issues. The Service Principal did not have the permissions to assign this role. The error then became: 

"Error: unexpected status 403 (403 Forbidden) with error: AuthorizationFailed: The client 'insert-application-id' with object id 'insert-object-id' does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write' over scope '/subscriptions/insert-subscription-id/resourceGroups/tf-storage-cmk/providers/Microsoft.KeyVault/vaults/insert-vault-name/providers/Microsoft.Authorization/roleAssignments/2a03aa3d-1d80-3ed0-760d-5610e324ee18' or the scope is invalid. If access was recently granted, please refresh your credentials."

This told me that the Service Principal had the permissions to **create** resources, but not the permissions to role assignments. Because this is a lab environment, I have given Terraform the 'Contributor' role so it can create resources broadly - however in practice it is probably better to define more granular permissions for the resources you might need it to create.

To get around this, in the GUI, I assigned the Terraform Service Principal the 'Role Based Access Control Administrator' IAM role at the scope of the subscription. Within this, I applied conditions to only be able to assign certain roles, being Key Vault Administrator (to assign to itself within the Terraform code) and Key Vault Crypto Service Encryption User (to assign to the Managed Identity that the Storage Account will use to authenticate to Key Vault). This prevents Terraform from being able to assign every role and therefore be used as a privilege escalation point (outside of Key Vault). 

*Note:* This would not be best practice, but is sufficient for lab purposes.

## Public Network Access
When setting up the Key Vault initially, I had public_network_access_enabled set to 'false' with the network_acls block to allow access to my IP address. However, setting this field to false overrides all network_acls rules which makes them redundant.

Also, according to [this](https://learn.microsoft.com/en-us/azure/key-vault/general/developers-guide) article, Key Vault uses a two-plane access model:
- Control Plane: Managing the Key Vault resource itself (creation, deletion, updating properties and assigning access policies) is done through Azure Resource Manager (ARM).
- Data Plane: Managing the data stored within Key Vault (keys, secrets, certificates) is done through RBAC. According to [this](https://learn.microsoft.com/en-us/azure/key-vault/general/secure-key-vault#network-security) article, blocking public access blocks data-plane connections.

Therefore, even though I had blocked public access I was able to perform actions on the Key Vault itself through the control plane. However, when it came to managing data within the Key Vault, i.e. creating the key - this action was blocked.

### To fix:
Set public_network_access_enabled to 'true' and add a network_acls {} block to allow my IP address through (obtained through a data.http.current_ip block so it is not hard-coded), with a default deny rule. This means that public access is **only** allowed from my IP address.

Overall, this was a fun lab to complete to implement a Storage Account that is encrypted with encryption keys under my control. In practice, there are a few things that can be done to follow best-practices:
- Configuring automated key rotation and expiration. Not necessary for this lab as the resources will be destroyed after creation anyway. This would satisfy CSA CEK-12: Key Rotation, CSA CEK-13: Key Revocation and CSA CEK-14: Key Destruction.
- Create backups of critical keys and store them securely. Important for keys that protect business critical data. Again, not necessary for this lab as resources will be destroyed after creation. Also, cost savings. This would satisfy CSA CEK-20: Key Recovery.
    - Along this vein, assign permissions to the *backup* key operation only to identities that need it.
- Locking down public access completely and using a Private Endpoint.
- Creating a custom role for Terraform to provide it with the minimum permissions it needs to create the resources needed for this lab. This would satisfy CSA IAM-05: Least Privilege.
- We have set up a Diagnostic Setting, however it would also be important to set up alerting for events, such as unusual access, failed key operations, key deletions/modifications and keys that are approaching expiration. This would satisfy CSA LOG-13: Failures and Anomalies Reporting.

# Controls Addressed
The controls referenced here will be from the Cloud Controls Matrix (CCM) developed by the Cloud Security Alliance (CSA).

**CSA CEK-03: Data Encryption - Provide cryptographic protection to data at-rest and in-transit, using cryptographic libraries certified to approved standards.**

This requirement is addressed by the following:
- Storage accounts are encrypted with an AES-256 key by default. Infrastructure encryption adds a second layer of encryption;
- Use of the customer-managed key; and 
- Only accepting TLS v1.2 or above traffic.
- Only accepting HTTPS traffic.

**CSA CEK-04: Encryption Algorithm - Use encryption algorithms that are appropriate for data protection, considering the classification of data, associated risks, and usability of the encryption technology.**

This requirement is addressed by the following:
- Storage accounts are encrypted with an AES-256 key by default. Infrastructure encryption adds a second layer of encryption;
- An RSA key with a 4096-bit length is used for the customer-managed key

**CSA CEK-20: Key Recovery - Define, implement and evaluate processes, procedures and technical measures to assess the risk to operational continuity versus the risk of the keying material and the information it protects being exposed if control of the keying material is lost, which include provisions for legal and regulatory requirements.**

This requirement is *partially* addressed by having soft delete and purge protection on. I haven't gone to the length of actually setting up recovery procedures.