---
title: 'Ansible Part 2: Azure Inventory'
date: '2019-07-06T22:22:10+01:00'
categories: [Ansible]
tags: [Ansible]
---

Series Table of contents:

- [Part 1: Install Ansible]({% post_url 2019-07-05-ansible-part-1-install-ansible %})
- Part 2: Azure Inventory

Ansible is a agentless system. So we have to write inventoryscripts targeting our environment. In my case It Is Azure. We use Ansible 2.8.1 so Red Hat changed the inventory mechanism. They now use a inventory plugins for Azure Resource Manger.

Now we need to define an Inventory. Change to "Inventories" and create a new one. Click on the Plus Sign and select Inventory.

![AWXInventoryScripts3-1](/assets/pictures/2019-07-06/AWXInventoryScripts3-1.jpg)

![AWXInventoryScripts4](/assets/pictures/2019-07-06/AWXInventoryScripts4.jpg)

To get the inventory up and running we need a Azure credential. This is a Service Principal Name that we have to register in Azure Active Directory. To do that you have to authenticate to your Microsoft Azure Subscription and go to Azure Active Directory.

![AAD1](/assets/pictures/2019-07-06/AAD1.jpg)

Go to App registration and create a "New registration"

![AAD2-1](/assets/pictures/2019-07-06/AAD2-1.jpg)

Give the Azure AD application a name and select the following settings:

Name: AnsibleBlog
Supported account types: Accounts in this organizational directory only (Standardverzeichnis)
Redirect URI (optional): Web, https://autologon.com (give It any url that you want)

![AAD3](/assets/pictures/2019-07-06/AAD3.jpg)

After that you select "Certificates &amp; secrets" and create a new client secret.

![AAD4-1](/assets/pictures/2019-07-06/AAD4-1.jpg)

Give It a description and for demo purposes set It to 1 year.

![AAD5](/assets/pictures/2019-07-06/AAD5.jpg)

make a note of the value. This is the password that we will need for the Ansible credential later. You should also take note of the following values. You find them in the Overview of the Azure AD application:

Subscription ID:

Go to "Subscriptions". Here you see your subscription id

![AAD7](/assets/pictures/2019-07-06/AAD7.jpg)

Client ID: see picture below
Tennant ID: see picture below
UserName: your Azure Login
Password: the password to the Azure Login

![AAD6](/assets/pictures/2019-07-06/AAD6.jpg)

The last step we have to do on the azure side is assign this service principal contributor rights to our subscripton. We do that by going to "Subscriptions". Click on your subscription and select “Access control (IAM)”.

![AAD8](/assets/pictures/2019-07-06/AAD8.jpg)

Assign the application that you created earlier the following rights

![AAD9](/assets/pictures/2019-07-06/AAD9.jpg)

Now we have all the information we need we are now able to create the Ansible Credential. Go to "Credentials" in AWX and create a new one.

![AWXInventoryScripts5-1](/assets/pictures/2019-07-06/AWXInventoryScripts5-1.jpg)

Give the credential a name and select the credential type to be "Microsoft Azure Resource Manager". After that we are able to see new fields provide them with the values that we collected before and click save. Client Secret is the value that you noted down earlier.

Now we have to assign the credential to the Inventory that we created before. Go to that inventory.

![AWXInventoryScripts6](/assets/pictures/2019-07-06/AWXInventoryScripts6.jpg)

Select sources from the buttons above.

![AWXInventoryScripts7](/assets/pictures/2019-07-06/AWXInventoryScripts7.jpg)

![AWXInventoryScripts8](/assets/pictures/2019-07-06/AWXInventoryScripts8.jpg)

Give the source a name and the source is "Microsoft Azure Resource Manager". The Credential is automatically filled out. If you want you can select a region to the source. Click Save

![AWXInventoryScripts9](/assets/pictures/2019-07-06/AWXInventoryScripts9.jpg)

If you want to start an Inventory click on "Inventories" chose your inventory and click the button sources and click on Sync All.

To watch the progress of your inventory go to the jobs view and klick on the job that is running to see the details.

That’s It for part 2. Watch out for part 3.