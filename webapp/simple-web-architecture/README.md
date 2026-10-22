# Simple Web Application Deployment

Largely following this [guide](https://learn.microsoft.com/en-us/azure/app-service/quickstart-python?tabs=flask%2Cwindows%2Cazure-portal%2Cazure-cli-deploy%2Cdeploy-instructions-azportal%2Cterminal-bash%2Cdeploy-instructions-zip-azcli) from MS Learn. This is purely just focusing on the infrastructure side of deploying a website, therefore I am not wanting to focus on the code that sits within the website. The Microsoft Learn guide handles the code for a basic dynamic web app, using Python and Flask.

## Deploying using GUI
*Note:* There will be no database, or CI/CD. Therefore the 'Database' and 'Deployment' tabs of the creation will be skipped in this instance. Additionally, the 'Monitor + secure' tab will be skipped, as Application Insights and Microsoft Defender for Cloud will incur charges.

### Basics Tab
This will be deployed to the MEL_Prod resource group, and named 'nigelstestwebapp'. Azure automatically generates the remainder of the URL.
- I have selected Python as the runtime stack, therefore only Linux is available.
- I have selected a deployment to Australia Central (note, at the time of this lab I have my Azure Policies disabled therefore deployments to non-Australia regions would be allowed).
- I have selected the Free plan, as this is a lab which will be temporary.
- I don't have a Linux Plan, so Azure will create one.

![GUI Basics 1.png](./assets/GUI%20Basics%201.png)
![GUI Basics 2.png](./assets/GUI%20Basics%202.png)

### Networking Tab

I will be enabling public network access in this lab, purely so I can access the web app from my personal laptop. Depending on the purpose of the web app, this may be on or off:
- On, if you do need public accessibility - completely standard deployment for public-facing websites. Or something like a load balancer or WAF may take initial public connections, only allowing access to the web server under specifically defined rules.
- Off, for example if this is an internal web app that should only be accessible by staff. For example, a web server hosting the admin portion of a public-facing website. You don't want the public to be able to access this. Azure deployments may use Private Endpoints instead for secure private access.

![GUI Networking Tab.png](./assets/GUI%20Networking%20Tab.png)

### Deployment
Then Review + Create to finalise. This will commence the deployment of the web app. To access the web app, the 'Overview' tab of the resource contains the URL to use.

![Overview tab w domain name.png](./assets/Overview%20tab%20w%20domain%20name.png)

When attempting to access the website, we see this screen. The web app is running; however there is no code, so there is nothing to show. We need to deploy the code.
![Web app waiting for content.png](./assets/Web%20app%20waiting%20for%20content.png)

Since I am unable to automatically build and deploy from a source repository (i.e. no CI/CD), App Service supports manual deployment, using a .zip file.

![Manual Deployment.png](./assets/Manual%20Deployment.png)

In a real, production environment, it is likely that CI/CD is deployed, complemented by automated testing etc. in a well-defined workflow. This automates the deployment of any code changes to the website, once testing (e.g. functional and security) has passed. However, for this simple set up CI/CD is not required, hence the basic manual deployment is fine. I also have not yet learned CI/CD, so this will come later down the learning journey.

### Access Restriction Change
In the portal, I am able to change access after-the-fact. Therefore, I have restricted access to just my personal IP address.

![Allow personal IP address.png](./assets/Allow%20personal%20IP%20address.png)

And, when we access the URL once again, the app is now up and running:

![Web App running.png](./assets/Web%20App%20running.png)

This covers the deployment of a very basic, fully managed web application. This is a very simple deployment, with minimal infrastructure to manage on the developer's part. Here, Microsoft looks after the web server itself, and all that is required is for the developer to worry about the application code. This is useful for:
- Small businesses/startups with minimal system administration expertise/resources/budget.
- Anyone learning web development, who just wants to focus on the code and not managing the infrastructure.

## Deploying Using Terraform
The Terraform project is structured as follows:

![Terraform project structure](./assets/TF%20project%20structure.png)

Where the key parts of the architecture are separated out. Here, the main resource is the [appservice](appservice.tf), which will be used to host the web app. The 'msdocs-python-flask-webapp-quickstart' directory contains the .zip file with Microsoft's bundled code (the same code deployed in the GUI implementation).

There are no real complexities to the code, as it is a simple deployment. The main things to point out:

**Service Plan**

I have used the 'F1' SKU for this value to ensure that the web app remains free. This is a very limited resource, with 1GB RAM, 1GB Storage and Shared Cores with 60 CPU minutes / day. This wouldn't be suitable for anything other than testing. In fact, Microsoft [explicitly says](https://azure.microsoft.com/en-us/pricing/details/app-service/linux/) that this tier is intended for trials and experimentation.

**Web App**

Since I am using a Python application stack, I will be using a Linux webapp.

Most of the action occurs in the 'site_config' block of the 'azurerm_linux_web_app' resource.

This is where the actual configuration of the webapp occurs. In here, I have only specified an ip_restriction block (to allow my device to access the application) and defined a catch-all 'Deny' rule to deny all other traffic not covered by this rule. Note that the ip_address line within the ip_restriction block [requires](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app#ip_address-1) a CIDR block.

Terraform's [documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app#always_on-1) notes that always_on must be explicitly set to 'false' when using Free, F1, D1 or Shared Service Plans. I have also specified python within the application_stack block, as this is what the pre-bundled code is written in.

### Deployment
After validating the code, the deployment is successful as shown below:
![Successful deployment](assets/Successful%20deployment.png)

However, we have not yet deployed any actual code to the web server, so there is nothing to display:

![Pending code](assets/tf%20deployment%20pending%20code.png)

Since we have not set up any CI/CD pipeline, this will be a manual deployment. The below Azure CLI prompt deploys the .zip file containing the website code to the webapp:

![Deploying code](assets/Deploying%20code%20via%20az%20CLI.png)

Waiting a couple of minutes, the website is now up and running.

![Website up and running](assets/Working%20tf%20deployment%20incl.%20code.png)

## How to Run
### Authentication & Permission Checks
First, if using Terraform via a Service Principal ensure environment variables have been exported to your terminal session. Otherwise, ensure you are logged in to the Azure CLI using az login. In this scenario, Terraform will be running with your personal permissions. Ensure that permissions are sufficient to deploy resources, and that the subscription is the correct subscription.

```bash
az login # If you want to login with Service Principal, add --service-principal --tenant --username and either (--password or --certificate) flags depending on the auth method.

az account set --subscription <subscription> # Set az cli to point to the correct subscription.

# List role assignments for the currently signed-in user, at the currently set subscription.
# Includes any roles inherited from higher up the hierarchy, and roles from any groups the user is part of.
az role assignment list --assignee "$(az ad signed-in-user show --query id -o tsv)" \
--scope "/subscriptions/$(az account show --query id -o tsv)" \
--include-inherited \
--include-groups \
--output table
```

### Terraform Workflow & Deploying Code
After checking authentication and permissions are correct, proceed to the standard Terraform workflow:

```bash
terraform init
terraform plan # Note this will prompt for project_name to be set as a variable, unless you explicitly set -var="project_name=<name>"
terraform apply 
```

Then, run the code to deploy the webapp:

```bash
az webapp deploy --subscription <subscription> -g <resource_group> -n <webapp_name> --src-path <path/to/zip/file>
```

After checking that everything works, destroy the resources.

```bash
terraform destroy
```