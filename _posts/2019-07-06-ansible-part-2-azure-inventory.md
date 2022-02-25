---
id: 314
title: 'Ansible Part 2: Azure Inventory'
date: '2019-07-06T22:22:10+01:00'
author: constantin
layout: post
guid: 'http://the-itguy.de/?p=314'
permalink: /ansible-part-2-azure-inventory/
php_everywhere_code:
    - 'Just put [php_everywhere] where you want the code to be executed.'
wpmdr_menu:
    - '2'
wptr_hide_title:
    - '0'
categories:
    - Ansible
---

Series Table of contents:

- [Part 1: Install Ansible](https://the-itguy.de/ansible-part-1-install-ansible/)
- Part 2: Azure Inventory

Ansible is a agentless system. So we have to write inventoryscripts targeting our environment. In my case It Is Azure. We use Ansible 2.8.1 so Red Hat changed the inventory mechanism. They now use a inventory plugins for Azure Resource Manger.

Now we need to define an Inventory. Change to “Inventories” and create a new one. Click on the Plus Sign and select Inventory.

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AWXInventoryScripts3-1-1024x504.jpg)</figure><figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AWXInventoryScripts4-1024x507.jpg)</figure>To get the inventory up and running we need a Azure credential. This is a Service Principal Name that we have to register in Azure Active Directory. To do that you have to authenticate to your Microsoft Azure Subscription and go to Azure Active Directory.

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AAD1-1024x534.jpg)</figure>Go to App registration and create a “New registration”

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AAD2-1-1024x545.jpg)</figure>Give the Azure AD application a name and select the following settings:

Name: AnsibleBlog  
Supported account types: Accounts in this organizational directory only (Standardverzeichnis)   
Redirect URI (optional): Web, https://autologon.com (give It any url that you want)

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AAD3.jpg)</figure>After that you select “Certificates &amp; secrets” and create a new client secret.

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AAD4-1-1024x456.jpg)</figure>Give It a description and for demo purposes set It to 1 year.

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AAD5-1024x518.jpg)</figure>make a note of the value. This is the password that we will need for the Ansible credential later. You should also take note of the following values. You find them in the Overview of the Azure AD application:

Subscription ID:

Go to “Subscriptions”. Here you see your subscription id

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AAD7.jpg)</figure>Client ID: see picture below  
Tennant ID: see picture below  
UserName: your Azure Login  
Password: the password to the Azure Login

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AAD6-1024x591.jpg)</figure>The last step we have to do on the azure side is assign this service principal contributor rights to our subscripton. We do that by going to “Subscriptions”. Click on your subscription and select “Access control (IAM)”.

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AAD8-1024x504.jpg)</figure>Assign the application that you created earlier the following rights

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AAD9.jpg)</figure>Now we have all the information we need we are now able to create the Ansible Credential. Go to “Credentials” in AWX and create a new one.

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AWXInventoryScripts5-1-1024x502.jpg)</figure>Give the credential a name and select the credential type to be “Microsoft Azure Resource Manager”. After that we are able to see new fields provide them with the values that we collected before and click save. Client Secret is the value that you noted down earlier.

Now we have to assign the credential to the Inventory that we created before. Go to that inventory.

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AWXInventoryScripts6-1024x242.jpg)</figure>Select sources from the buttons above.

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AWXInventoryScripts7-1024x318.jpg)</figure><figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AWXInventoryScripts8-1024x255.jpg)</figure>Give the source a name and the source is “Microsoft Azure Resource Manager”. The Credential is automatically filled out. If you want you can select a region to the source. Click Save

<figure class="wp-block-image">![](https://the-itguy.de/wp-content/uploads/2019/07/AWXInventoryScripts9-1024x422.jpg)</figure>If you want to start an Inventory click on “Inventories” chose your inventory and click the button sources and click on Sync All.

To watch the progress of your inventory go to the jobs view and klick on the job that is running to see the details.

That’s It for part 2. Watch out for part 3.