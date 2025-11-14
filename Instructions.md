### Lab TF00 - Set Up Environment for Terraform Labs
#### Objective
Get access to a cloud environment against which to run terraform commands

#### Outcomes
By the end of this lab, you will have:
* Accessed the GCP cloud console
* Configured cloud service account credentials
* Installed Terraform

#### High-Level Steps
* log into the cloud console
* generate cloud service account credentials
* configure local environment variables
* install terraform

#### Detailed Steps
##### Configuring Cloud Access
1. If you have not already done so, sign up for a [QwikLabs](https://qa.qwiklabs.com) account, and provide the email used for signup to your instructor, so that they can add you to the classroom
2. Once you have been added to the classroom, refresh QwikLabs and click on the tile that says 'BOAQAAIP Terraform' to enter the classroom. 
3. From there, navigate into the lab itself, and click 'Start Lab' - this will create a new GCP environment
4. From the environment details, copy the GCP project ID - you will need this shortly
5. Right-click the 'open console' button and click 'open in incognito/inprivate window'. This will log you into the Google Cloud console.
6. Once in the cloud console, navigate to IaM and Admin > Service Accounts, and click on the service account name for the qwiklabs user
7. Navigate to the 'keys' tab, and click add > create new key. Leave the type as JSON and click create. The keyfile should automatically download.
8. While you are in the cloud console, navigate to Compute Engine > metadata. Edit the metadata and set enable-oslogin to false. This will be important later.
9. Ensure you have an open VSCode window connected to WSL, with your home directory open in the explorer
10. From your downloads, drag and drop the keyfile into the VSCode file explorer to move it into your WSL home directory
11. In a VSCode integrated terminal, run the following:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="~/<name_of_keyfile>.json"
echo !! | tee -a ~/.bashrc
export TF_VAR_gcp_project="<project ID you copied from qwiklabs>"
echo !! | tee -a ~/.bashrc
export TF_VAR_pubkey_path="$HOME/ansible_key.pub"
echo !! | tee -a ~/.bashrc
git clone https://github.com/qa-tech-training/BOAQAAIP_DAY3_LABS.git ~/Labs3 # clone this repo
``` 
##### Installing Terraform
12. Download and extract the Terraform binary using the provided script:
```bash
. ~/Labs3/TF00/install_terraform.sh
```
13. Verify the installation: `terraform version`

### Lab TF01 - Terraform Key Concepts

#### Objective
Deploy a cloud compute resource to a custom cloud network using Terraform

#### Outcomes
By the end of this lab, you will have:
* Used a Terraform provider and Terraform resources to manage compute and network infrastructure
* Reviewed the concept of state

#### High-Level Steps
* configure a terraform provider
* create a basic cloud compute resource
* configure networking via terraform
* use a startup script to deploy software as part of initialisation

#### Detailed Steps
##### Create a compute instance
1. In your terminal, switch to the TF01 directory: `cd ~/Labs3/TF01`, and expand this directory in the VSCode file explorer.
2. Open the main.tf file, and add the following:
```terraform
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "7.7.0"
    }
  }
}

variable "gcp_project" {}

provider "google" {
    project = var.gcp_project
    region = "us-east1"
}
```
see the [google provider documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs) for details on more configuration options
3. Once you have set up the provider configuration, run:
```shell
terraform init
```
At this point, Terraform will install the provider, as well as initialising a few other things, some of which we will see later
4. Review the [documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) for the google_compute_instance resource type. Add, to the instance.tf file, a block defining a VM with the following configuration:
* name: demo-instance-1
* machine type: e2-medium
* zone: us-east1-b
* boot disk image: debian 12
* network: default
* network access tier: standard

See the solution below if needed.

##### Solution 1 - Compute Instance
```terraform
resource "google_compute_instance" "vm1" {
  name         = "demo-instance-1"
  machine_type = "e2-medium"
  zone         = "us-east1-b"

  allow_stopping_for_update = true
  
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  
  network_interface {
    network = "default"

    access_config {
      network_tier = "STANDARD"
    }
  }
}
```

##### Deploy the Instance
5. Plan and create the resource:
```shell
terraform plan
terraform apply
```
Enter 'yes' to confirm the apply when prompted.  

6. Once the apply is complete, navigate to the compute engine > VM instances - you should see a new VM instance.
7. Review the newly-created _terraform.tfstate_ file - this is how Terraform tracks the resources that it is managing.
8. Destroy the VM: `terraform destroy` (entering 'yes' to confirm destruction when prompted)
9. Review the tfstate file again - note that it now contains no resources, as the instance has been deleted
10. Before moving on, comment out the contents of the instance.tf file (in VSCode editor, highlight everything and hit ctrl+/)

##### Deploying the network
11. We will now redeploy our instance, but onto a custom network. Open the _network.tf_ file, and add the following resources:
* a network named 'custom-vpc'
* a custom subnetwork for the custom network with the following configuration:
  * name: custom-subnet
  * ip cidr range: 10.0.1.0/24
  * region: us-east1  

For guidance, consult the following documentation:
* [network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network)
* [subnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork)  

And see the solution below if needed

##### Solution 2 - Network Configuration
```terraform
resource "google_compute_network" "lab-vpc" {
  name                    = "custom-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "lab-subnet" {
  name          = "custom-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-east1"
  network       = google_compute_network.lab-vpc.id
}
```
12. Plan and apply the network deployment:
```shell
terraform plan
terraform apply
```
When, prompted, enter 'yes' to confirm the apply.

##### Configuring the firewall
13. To make compute instances in our new network accessible, the network will require a firewall allowing relevant access. Add a firewall resource to _firewall.tf_, with the following config:
* name: custom firewall
* network: the custom network we created above
* allowed ports: 8080 and 8081
* a single source range of 0.0.0.0/0  

For guidance, consult the [firewall documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall), and see solution below if required:

##### Solution 3 - Firewall Config
```terraform
resource "google_compute_firewall" "lab-firewall" {
  name    = "custom-firewall"
  network = google_compute_network.lab-vpc.name

  allow {
    protocol = "tcp"
    ports    = [8080, 8081]
  }

  source_ranges = ["0.0.0.0/0"]
}
```
14. To add the firewall to the network, perform another plan and apply:
```shell
terraform plan
terraform apply
```

##### Deploy the VM
15. Finally, we will deploy a VM into the custom network we have created. Uncomment the contents of instance.tf and make the following change on line 15:
```terraform
    subnetwork = google_compute_subnetwork.lab-subnet.name
```
Perform another plan and apply:
```shell
terraform plan
terraform apply
```
Once the apply is complete, the instance should appear in the compute engine in the console.

##### Making use of the ports
16. We can make this a more interesting deployment by making a small change to the instance configuration. Add the following to the instance resource, in your instance.tf file:
```terraform
  metadata_startup_script=file("deploy.sh")
```
17. Re-run the terraform plan & apply:
```shell
terraform plan
terraform apply
```
18. The instance will be destroyed and recreated, and the new instance will run the provided script on boot. Once the new instance is started, you should be able to access the following ports on the VM's external IP:
- 8080: should display the default NGINX landing page
- 8081: should display the Apache 'It Works!' response

##### Clean up
19. To clean up the resources created by terraform, perform a terraform destroy:
```shell
terraform destroy
```
Again typing 'yes' to confirm when prompted.

### Lab TF02 - Work With Terraform Modules

#### Objective
Modularise a complex Terraform deployment, to enable greater reusability

#### Outcomes
By the end of this lab, you will have:
* Created reusable Terraform modules defining compute and network resources
* Configured variables and outputs to pass data to/from modules
* Used modules as part of a complex deployment

#### High-Level Steps
* Decompose existing configuration into modular structure
* Define variables and parameterise resources
* Define outputs to move data between modules
* Reference child modules from root module

#### Detailed Steps
##### Configuring the modules
1. Change directory into the lab folder: `cd ~/Labs3/TF02`, and review the starting point for the lab. Terraform, like Python, allows the importing of code from another source for use as a _module_

2. Begin by breaking up your existing configuration from the previous lab:
* `instance/main.tf` should contain the google_compute_instance resource block
* `network/main.tf` should contain the google_compute_network, google_compute_subnetwork and google_compute_firewall blocks
* the root `main.tf` file should contain only the provider configuration, for now

3. Now we can begin parameterising the existing code using _variables_, for better reusability. Open `network/variables.tf` and add the following:
```terraform
variable "network_name" {}
variable "ip_cidr_range" {}
variable "allowed_ports" {}
variable "region" {}
```
3. We can then parameterize the `network/main.tf` file using these values. You should be able to work out where they go from the variable names, but see solution below if needed.
4. Now do the same for the instance. Add the following contents to `instance/variables.tf`:
```terraform
variable "instance_name" {}
variable "region" {}
variable "machine_type" {}
variable "subnet_name" {}
variable "script_path" {}
```
And update `instance/main.tf` to use these variables - again, see solution below if needed.

##### Solutions to This Point
`network/main.tf` contents:
```terraform
resource "google_compute_network" "lab-vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "lab-subnet" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.ip_cidr_range
  region        = var.region
  network       = google_compute_network.lab-vpc.id
}

resource "google_compute_firewall" "lab-firewall" {
  name    = "${var.network_name}-firewall"
  network = google_compute_network.lab-vpc.name

  allow {
    protocol = "tcp"
    ports    = var.allowed_ports
  }

  source_ranges = ["0.0.0.0/0"]
}
```
`instance/main.tf` contents:
```terraform
resource "google_compute_instance" "vm" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = "${var.region}-b"

  allow_stopping_for_update = true
  
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  
  metadata_startup_script = file(var.script_path)
  
  network_interface {
    subnetwork = var.subnet_name

    access_config {
      network_tier = "STANDARD"
    }
  }
}
```

##### Adding Outputs
5. There is one more thing needed. Since the subnet and instance are defined in separate modules, the instance cannot access the subnet name directly from the resource as we did previously. Instead, the network module must expose the subnet name as an *output* which can then be passed to the instance module. Add the following to `network/outputs.tf`:
```terraform
output "subnet_name" {
  value = google_compute_subnetwork.lab-subnet.name
}
```
7. While we are configuring outputs, let us add an output to the instance module as well:
```terraform
output "vm_ip" {
  value = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}
```

##### Using the modules
8. Now that our modules are set up, we can call them from main.tf. Edit the root main.tf and add the following to what is already there:
```terraform
module "network" {
  source = "./network"
  network_name = "lab2-vpc"
  region = "us-east1"
  allowed_ports = ["22", "80", "8080", "8081"]
  ip_cidr_range = "10.0.1.0/24"
}

module "server" {
  source = "./instance"
  region = "us-east1"
  subnet_name = module.network.subnet_name
  machine_type = "e2-medium"
  instance_name = "app-server"
  script_path = "${path.root}/deploy.sh"
}
```
9. To make sure that we get the VM IP, add the following to `outputs.tf`:
```terraform
output "server_ip" {
  value = module.server.vm_ip
}
```

10. Deploy the resources using the init-plan-apply workflow:
```shell
terraform init
terraform plan
terraform apply
```

11. Once the apply is complete, you should see the server_ip output in the terminal. Test that the deployment worked:
```shell
curl http://<server_ip>:8080
curl http://<server_ip>:8081
```

### Leveraging reusability
12. Now that we have modularised this deployment, we could use these same modules to create as many VPC and compute instance resources as we need. To demonstrate this, we will deploy a second instance. Add another module using instance/ as its' source to main.tf, like so:
```terraform
module "proxy" {
  source = "./instance"
  region = "us-east1"
  subnet_name = module.network.subnet_name
  machine_type = "e2-medium"
  instance_name = "proxy-server"
  script_path = "${path.root}/proxy.sh"
}
```

13. And add another output to `outputs.tf`:
```terraform
output "proxy_ip" {
  value = module.proxy.vm_ip
}
```

14. The provided proxy.sh script will need to be updated with the correct IP address - there are many ways we could do this, but for now we will use sed:
```bash
sed -i 's,{{ SERVER_IP }},<your server ip>,g;' proxy.sh
```

15. Once again, init, plan and apply the deployment - only the new instance should need to be created. 
```shell
terraform init # needs to be re-run because we've added a new module
terraform plan
terraform apply
```

16. Once the apply is complete, grab the value of the proxy_ip output, and test it with curl:
```shell
curl http://<proxy_ip>/nginx # should return nginx landing page
curl http://<proxy_ip>/apache # should return It Works!
```

### Clean up
17. To clean up the resources created by terraform, perform a terraform destroy:
```shell
terraform destroy
```

### Lab ANS01 - Ansible Introduction

#### Objective
Use ansible to deploy a webserver resource locally

#### Outcomes
By the end of this lab, you will have:
* Installed Ansible
* Used an ad-hoc command to configure a local webserver

#### High-Level Steps
* Install Ansible
* Install NGINX via an ad-hoc command
* Uninstall NGINX via an ad-hoc command

#### Detailed Steps
##### Installation
1. You can install Ansible in many ways, here we are going to use `apt`. Switch into the ANS01 directory and run the provided install script:
```bash
cd ~/Labs3/ANS01
./install_ansible.sh
```

##### Use Ansible to Install a Web Server
2. Now we are going to run an ad-hoc command to install NGINX.

```bash
ansible 127.0.0.1 -m apt -a "name=nginx state=present update_cache=true" --become
```

`-m apt` is letting Ansible know to use the `apt` module and the `-a` defines any arguments to pass to that module. `--become` is giving us sudo privileges for this play. 

You should see that Ansible returns a JSON object, showing you that it has completed the task. 

##### Check NGINX has been Installed Correctly
3. The `curl` command can be used to check that our web server is running correctly:
```bash
curl http://localhost
```
You should get a response back similar to this:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

4. Run the ansible command again. You should see that the execution is a lot quicker and that you get a different output, like this:
```bash
ansible 127.0.0.1 -m apt -a "name=nginx state=present update_cache=true" --become
```
```
localhost | SUCCESS => {
    "cache_update_time": 1612268706, 
    "cache_updated": true, 
    "changed": false
}
```
We can see that the changed value is false; this means Ansible noticed that NGINX was already installed and didn't make any changes, as the state is already present. You can run this command as many times as you like and you will get a success message.
5. We will now remove nginx, so that we can install it again in a subsequent lab. Run the following:
```bash
ansible 127.0.0.1 -m apt -a "name=nginx state=absent update_cache=true" --become
```
Note the change here: state=absent instead of state=present

### Lab ANS02 - Ansible Playbooks and Inventories

#### Objective
Use an Ansible playbook to define a configuration job declaratively and execute it against an inventory of cloud targets

#### Outcomes
By the end of this lab, you will have:
* Created an Ansible playbook
* Executed a playbook using Ansible

#### High-Level Steps
* Use an Ansible _playbook_ to configure a local host
* Define a _static inventory_ of remote hosts to configure
* Use a _dynamic inventory_ to automatically detect remote targets

#### Detailed Steps
##### Setup
1. Start by switching into the ANS02 lab directory:
```bash
cd ~/Labs3/ANS02
```

##### NGINX Configuration
2. NGINX web server is configured using a `.conf` file. Review the provided nginx.conf:
```conf
events {}
http {
    server {
       listen 80;
       location / {
            return 200 "Hello new nginx\n";
        }
    } 
}
```
This will eventually change what NGINX presents.

##### Ansible Playbook
3. Open the playbook.yml file, and review the contents:
```yaml
- hosts: localhost
  connection: local
  become: true
  tasks: []
```
This defines a single, currently empty _play_, targeting the local machine. A play is made up of _tasks_, which are the individual configuration actions required by the play. A _playbook_ can define one or more plays.
4. With reference to the documentation for the [apt](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/apt_module.html) module, add a task to this play which installs nginx - i.e. the same outcome as we acheived with the ad-hoc command previously. See the solution below if required

##### Playbook - Solution 1
```yaml
- hosts: localhost
  connection: local
  become: true
  tasks:
  - name: Install NGINX
    apt:
      name: nginx
      state: present
      update_cache: true
```

##### Apply the configuration
5. Using the `ansible-playbook` command, apply the configuration:
```bash
ansible-playbook playbook.yml
```
6. Now you can perform the curl command to check that NGINX is installed.
```bash
curl localhost
```
You should see something like this:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

##### New configurations
7. Now add two more tasks to the playbook - one to copy the custom nginx configuration from the local workspace to /etc/nginx/nginx.conf, and one to restart the NGINX service to ensure the new configuration is loaded. Refer to the docs for the [copy](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/copy_module.html) and [service](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/service_module.html) modules, and see solution below if needed  

##### Playbook - Solution 2
```yaml
- hosts: localhost
  connection: local
  become: true
  tasks:
  - name: install nginx
    apt:
      name: nginx
      state: present
      update_cache: true
  
  - name: Copy nginx file over
    copy:
      src: nginx.conf
      dest: /etc/nginx/nginx.conf
    register: nginx_config

  - name: Restart nginx if needed
    service:
      name: nginx
      state: restarted
```

8. Re-run the playbook:
```bash
ansible-playbook playbook.yml
```
You should see this in the output:

```
TASK [Restart nginx if needed] ***************************************************************************************************************************************************
changed: [localhost]
```

9. Now see what NGINX is showing.
```bash
curl localhost
```
You should see:
```
Hello new nginx
```
10. Run the playbook again. Notice that, even though nothing has changed, NGINX still gets restarted. This can be improved upon by adding a condition to the task that restarts NGINX, to only execute when the copy task changes something. Amend the restart nginx task like so:
```yaml
  - name: Restart nginx if needed
    service:
      name: nginx
      state: restarted
    when: nginx_config.changed == true # add this line
```
11. Now run the playbook again and see how the output changes.
```bash
ansible-playbook playbook.yml
```
Now the same section in the output should say this.
```
TASK [Restart nginx if needed] ***************************************************************************************************************************************************
skipping: [localhost]
```
It has skipped that last section because the copy section was unchanged.

##### Working With Inventories
So far we have run all of our tasks against localhost. The real power of Ansible lies in its' ability to configure remote hosts. For this, we must make remote host information available to Ansible via an _inventory_

##### Configure SSH Keys
When connecting to remote linux hosts, Ansible uses SSH. This means we will need an SSH key that Ansible can use to connect to the instances we will be working with. 
1. Generate a new SSH key pair - we will reuse this key pair a lot, so for convenience place it in your home directory:
```bash
ssh-keygen -q -t ed25519 -f ~/ansible_key # make sure to leave the key WITHOUT a passphrase
```

##### Provision Instances
Now that we have a key pair, we can provision some instances. The lab folder already contains the necessary Terraform files to deploy a set of VMs onto a network with access to required ports. Feel free to review the terraform configuration - it should be mostly familiar to you.
2. Provision the infrastructure by following the usual terraform workflow:
```bash
cd ~/Labs3/ANS02/terraform
terraform init
terraform plan 
terraform apply 
```
3. Wait for the apply to finish. Once the apply is complete, make a note of the IPs of your VMs as displayed by the Terraform outputs.

##### Connectivity Check
4. Before continuing, it would be a good idea to check that everything is configured correctly for SSH. For each of the IP addresses output by terraform, run the following:
```bash
ssh -i ~/ansible_key ansible@<ip_address>
```
When prompted, enter 'yes' to trust the host keys from the VMs.  
Note: the username 'ansible' is important, as this is the username for which the public SSH key has been added to the VMs.

##### Creating the inventory
Now that we have remote hosts, configured for SSH access, we can use an inventory to provide this information to Ansible. 
5. Edit the _inventory.yml_ file, filling in your IP addresses:
```yaml
all:
  children:
    test:
      hosts:
        IP_OF_HOST_1: # replace 
        IP_OF_HOST_2: # replace
        IP_OF_HOST_3: # replace
      vars:
        ansible_user: ansible
        ansible_ssh_private_key_file: '~/ansible_key'
```
This defines a single group of hosts, called 'all', with one subgroup called 'test'. We have also defined the ansible user and SSH key file to use to make the SSH connection.

##### Playbook
6. Open the _test\_playbook.yml_ file, and add the following contents:
```yaml
---
- hosts: all
  name: Ping Hosts
  tasks:
  - name: "Ping {{ inventory_hostname }}"
    ping:
    register: ping_info
  
  - name: "Show ping_info in console"
    debug:
      msg: "{{ ping_info }}"
```
All this playbook does is tell Ansible to connect to all hosts defined in the inventory file, and run the `ping` module.

7. This playbook will confirm that we can successfully connect to all of the hosts and execute tasks on them:
```bash
ansible-playbook -v -i inventory.yml test_playbook.yml
```
You should see output similar to the following, indicating that Ansible was able to connect successfully to the hosts configured in the inventory file:

```text
<output omitted>
TASK [Show ping_info in console] ************************************************************************************
ok: [IP_OF_HOST_1] => {
    "msg": {
        "changed": false, 
        "failed": false, 
        "ping": "pong"
    }
}
ok: [IP_OF_HOST_2] => {
    "msg": {
        "changed": false, 
        "failed": false, 
        "ping": "pong"
    }
}
ok: [IP_OF_HOST_3] => {
    "msg": {
        "changed": false, 
        "failed": false, 
        "ping": "pong"
    }
}

PLAY RECAP **********************************************************************************************************
IP_OF_HOST_1                     : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
IP_OF_HOST_2                     : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
IP_OF_HOST_3                     : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0  
```
8. Update the test_playbook to install nginx and git on the remote servers - refer back to previous solutions if needed

##### Using a Dynamic Inventory
The inventory file we have just created, with hardcoded host IPs, is called a _static inventory_. This is not particularly useful when configuring environments that have ephemeral infrastructure, with instances being constantly provisioned and deprovisioned. For such environments, we can instead use _dynamic inventories_ to automatically detect and group hosts within a cloud environment.  
9. Destroy the existing instances, and create new ones:
```bash
cd ~/Labs3/ANS02/terraform
terraform destroy 
terraform apply 
```
This will create new instances with new IP addresses.

10. Review the provided `inventory.gcp_compute.template.yml`. THis uses the relevant dynamic inventory plugin to query GCP for instances, and construct an inventory from the results - see the [documentation](https://docs.ansible.com/projects/ansible/latest/collections/google/cloud/gcp_compute_inventory.html) for the plugin for more details

11. Before we can use the plugin, we need a few more things.
* Ansible needs access to the google-auth python package to be able to authenticate to GCP:
```bash
sudo apt-get update
sudo apt-get install python3-google-auth
```
* The inventory file currently holds a placeholder for the project - we can fill this in using the ansible _template_ module:
```bash
cd ~/Labs3/ANS02
ansible 127.0.0.1 -m template -a "src=$(pwd)/inventory.gcp_compute.template.yml dest=$(pwd)/inventory.gcp_compute.yml" -e "GCP_PROJECT=$TF_VAR_gcp_project"
```

12. Verify that the new inventory can detect the new hosts:
```bash
ansible-inventory -i inventory.gcp_compute.yml --list
```
13. In order to execute playbooks against these dynamically detected hosts, there is one thing missing - the SSH configuration. Since this will not be included in the generated inventory, we will need to define this information somewhere else. One way to do this is via a config file, _ansible.cfg_, in the same directory as our inventory and playbook:
```ini
[defaults]
  remote_user=ansible
  private_key_file=~/ansible_key

[ssh_connection]
  ssh_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
```
This defines the user and keyfile that were previously set in inventory.yml, and also disables host key checking.  

14. You can now use the dynamic inventory to run the same playbook as before against the new hosts:
```bash
ansible-playbook -i inventory.gcp_compute.yml test_playbook.yml
```
15. As before, test that NGINX has been successfully installed using curl.

##### Clean Up
16. Destroy the resources you have created:
```bash
cd ~/Labs3/ANS02/terraform
terraform destroy 
```

### Lab ANS03 - Variables, Handlers, Facts and Templates

#### Objective
Parameterise Ansible configuration files and enhance the reusability of Ansible config.

#### Outcomes
By the end of this lab, you will have:
* Used variables and facts to parameterise an Ansible playbook
* Used Ansible's template module to dynamically alter the contents of a file
* Used handlers to make individual tasks repeatable on-demand
* Used a role to streamline the reuse of Ansible configuration 

#### High-Level Steps
* Parameterise the existing playbook
* Use Jinja2 templating to parameterise files
* Decompose existing config into roles

#### Detailed Steps

##### Deploy the Infrastructure
1. We can use the same terrform files from the previous lab to provision some target infrastructure for this lab. Change directory into the folder and apply the configuration:
```bash
cd ~/Labs3/ANS02/terraform
terraform plan 
terraform apply 
```
2. Make a note of the server IPs and proxy IP outputs, as we will use these later

##### Starting Point - Playbook, Inventory and NGINX Configs
Change into the ANS03 directory, and review the initial playbook state:
```yaml
---
- hosts: all
  become: true
  tasks:
  - name: Install NGINX
    apt:
      pkg: 
      - nginx
      - git
      state: latest
      update_cache: true
  - name: Start NGINX Service
    service:
      name: nginx
      state: started
- hosts: gcp_role_appserver
  become: true
  tasks:
  - name: 'update website from the git repository'
    git:
      repo: "https://gitlab.com/qacdevops/static-website-example"
      dest: "/opt/static-website-example"
  - name: 'install the nginx.conf file on to the remote machine'
    copy:
      src: nginx-server.conf
      dest: /etc/nginx/nginx.conf
  - name: Restart NGINX Service
    service:
      name: nginx
      state: restarted
- hosts: gcp_role_proxy
  become: true
  tasks:
  - name: transfer_nginx_conf
    copy:
      src: nginx-proxy.conf
      dest: /etc/nginx/nginx.conf
  - name: Restart NGINX Service
    service:
      name: nginx
      state: restarted
```
The logic here is:
* Install NGINX and git on all hosts
* Setup a static website on the appserver hosts, and supply a custom nginx.conf to serve it
* For the proxy, supply a custom NGINX config which will load balance between the appservers.

4. Next, render inventory.gcp_compute.template.yml to fill in your project ID
```bash
cd ~/Labs3/ANS03
ansible 127.0.0.1 -m template -a "src=$(pwd)/inventory.gcp_compute.template.yml dest=$(pwd)/inventory.gcp_compute.yml" -e "GCP_PROJECT=$TF_VAR_gcp_project"
```
5. Now edit lines 5 and 6 in the nginx-proxy.conf file and add the server IP addresses you noted earlier (Note: be careful to use the server IPs, NOT the proxy IP):
```conf
    upstream appservers {
        server SERVER_1_IP:8080; # <- edit this line
        server SERVER_2_IP:8080; # <- and this one
    }
```
6. Execute the playbook:
```bash
ansible-playbook -i inventory.gcp_compute.yml playbook.yml
```
7. Once the execution is complete, navigate to the proxy IP in a browser - you should be presented with the static website.  
8. Before moving on, destroy and recreate the infrastructure, so that we have a clean slate for the next part of the lab:
```bash
cd ~/Labs3/ANS02/terraform
terraform destroy 
terraform apply 
```
When the apply is complete, note the new proxy IP.

##### Improvements
So far, whilst this is a longer playbook than those we have used previously, everything we have done should be fairly familiar from previous activities. We will now introduce some new concepts to improve upon the basic playbook we have created, using _variables_, _handlers_, _roles_ and _templates_:
* _Variables_ allow for parameterised execution of playbooks - the same playbook could be executed against the same set of hosts, with different parameters leading to possibly very different results. This ensures greater reusability of playbooks.
* _Handlers_ are, in effect, tasks within a playbook that can be triggered on-demand by a notification from another task.
* _Roles_ are, in effect, what modules are to terraform - directories containing a collection of tasks and other resources which can then be referenced within playbooks, in order to streamline the re-use of complex configurations
* _Templates_ are used to dynamically alter the contents of a file before copying to a remote host, allowing for reuse of config files.  

9. We will start by using some variables to parameterise the playbook. Edit lines 21 and 22 in the playbook and replace the hard-coded information with variables:
```yaml
...
  - name: 'update website from the git repository'
    git:
      repo: "{{ repository_url }}" # <- edit this line
      dest: "{{ install_dir }}"    # <- and this one
...
```
Now the repository and the install directory are parameterised, we could potentially re-use this playbook to install any repository into any location on the target hosts.  

10. Next, we will reconfigure the nginx config files to act as templates. Starting with nginx-server.conf, edit line 5:
```conf
        root {{ install_dir }}; # <- add the template expression here
```
Ansible templates will be rendered by the _Jinja2_ templating engine prior to transfer to the host, allowing for injection of dynamic parameters. The server config is a fairly simple template, referencing the same install_dir variable as in the playbook. We can also use templates to improve the proxy config.  

11. Replace the contents of nginx-proxy.conf with the following:
```conf
events {}

http {
    upstream appservers {
        {% for host in groups['gcp_role_appserver'] %}
        server {{ hostvars[host]['ansible_facts']['default_ipv4']['address'] }}:8080;
        {% endfor %}
    }
    server {
        listen 80;
        location / {
            proxy_pass http://appservers;
        }
    }
}
```
This is a slightly more complex template which uses a for-loop over the hosts in the gcp_role_appserver group to dynamically construct the upstream, using _facts_ about the hosts to retrieve the IP addresses.  

12. To use these templates effectively, we must also update the playbook again, replacing 'copy' with 'template' on lines 24 and 35. 

13. The full playbook should now look like:
```yaml
---
- hosts: all
  become: true
  tasks:
  - name: Install NGINX
    apt:
      pkg: 
      - nginx
      - git
      state: latest
      update_cache: true
  - name: Start NGINX Service
    service:
      name: nginx
      state: started
- hosts: gcp_role_appserver
  become: true
  tasks:
  - name: 'update website from the git repository'
    git:
      repo: "{{ repository_url }}"
      dest: "{{ install_dir }}"
  - name: 'install the nginx.conf file on to the remote machine'
    template:
      src: nginx-server.conf
      dest: /etc/nginx/nginx.conf
  - name: Restart NGINX Service
    service:
      name: nginx
      state: restarted
- hosts: gcp_role_proxy
  become: true
  tasks:
  - name: transfer_nginx_conf
    template:
      src: nginx-proxy.conf
      dest: /etc/nginx/nginx.conf
  - name: Restart NGINX Service
    service:
      name: nginx
      state: restarted
```

14. Execute the playbook:
```bash
cd ~/Labs3/ANS03
ansible-playbook -i inventory.gcp_compute.yml playbook.yml -e "repository_url=https://gitlab.com/qacdevops/static-website-example install_dir=/opt/static-website-example"
```

15. Once execution is complete you should again be able to access the website by navigating to the proxy IP in a browser. 

16. Destroy and recreate the infrastructure again, to give us a clean slate:
```bash
cd ~/Labs3/ANS02/terraform
terraform destroy 
terraform apply 
```

##### Handlers and Roles
17. We can now make a few more changes to our configuration to reduce a lot of the repetition and improve reusability. We will start by initialising 3 _roles_:
```bash
cd ~/Labs3/ANS03
ansible-galaxy init common
ansible-galaxy init appserver
ansible-galaxy init proxy
```
A role defines a collection of tasks, templates, variables and other data which can then by used within a playbook without having to duplicate the config. We will configure the three roles to hold most of our configuration.  

18. Backup your existing playbook, for comparison later:
```bash
cp playbook.yml playbook-old.yml
``` 

19. Move the 'Install NGINX' and 'Start NGINX Service' tasks from _playbook.yml_ to _common/tasks/main.yml_
20. Move the 'update website from the git repository' and 'install the nginx.conf file on to the remote machine' tasks from _playbook.yml_ to _appserver/tasks/main.yml_
21. Move the 'transfer_nginx_conf' task from _playbook.yml_ to _proxy/tasks/main.yml_
22. Copy the two nginx.conf templates into their respective roles' templates directory:
```bash
cp nginx-server.conf appserver/templates/nginx-server.conf
cp nginx-proxy.conf proxy/templates/nginx-proxy.conf
```
23. Now that we have our roles, we will define a _handler_ for restarting NGINX, to avoid duplicated tasks. Add the following to _common/handlers/main.yml_:
```yaml
- name: restart nginx
  service:
    name: nginx
    state: restarted
```
24. Now, go through the tasks for each of your roles, and add the following to each of the templating tasks:
```yaml
  notify: restart nginx
```

##### Solutions
The files we have edited so far should now hold the following contents
* `common/tasks/main.yml`:
```yaml
---
- name: Install NGINX
  apt:
    pkg: 
    - nginx
    - git
    state: latest
    update_cache: true
- name: Start NGINX Service
  service:
    name: nginx
    state: started
```
* `common/handlers/main.yml`:
```yaml
---
- name: restart nginx
  service:
    name: nginx
    state: restarted
```
* `appserver/tasks/main.yml`:
```yaml
---
- name: 'update website from the git repository'
  git:
    repo: "{{ repository_url }}"
    dest: "{{ install_dir }}"
- name: 'install the nginx.conf file on to the remote machine'
  template:
    src: nginx-server.conf
    dest: /etc/nginx/nginx.conf
  notify: restart nginx
```
* `proxy/tasks/main.yml`:
```yaml
---
- name: transfer_nginx_conf
  template:
    src: nginx-proxy.conf
    dest: /etc/nginx/nginx.conf
  notify: restart nginx
```

25. Now with most of our configuration separated out into roles, the playbook itself can become much simpler:
```yaml
---
- hosts: gcp_role_appserver
  become: true
  vars:
    repository_url: "https://gitlab.com/qacdevops/static-website-example"
    install_dir: "/opt/static-website-example"
  roles:
  - common
  - appserver
- hosts: gcp_role_proxy
  become: true
  roles:
  - common
  - proxy
```
26. Executing the playbook and navigating to the proxy IP in a browser should, again, result in the website being accessible:
```bash
ansible-playbook -i inventory.gcp_compute.yml playbook.yml
```

### Lab ANS0X - Optional Stretch Goal
If you have completed the main labs, you should be able to synthesise what you have covered to:
* provision a compute instance, on a custom network, with a firewall exposing ports 22 and 5000
* Set up a dynamic inventory
* set up a playbook which targets your compute instance and:
  * installs git and docker
  * clones the sample flask API from yesterday: (this can be found in its' own repo at https://github.com/qa-tech-training/example_python_flask_apiserver.git)
  * uses docker to build the container image and deploy a container from it (hint: see the documentation for the Ansible [community.docker](https://docs.ansible.com/projects/ansible/latest/collections/community/docker/index.html) collection)
You might also then be able to amend your playbook to:
* install the docker compose plugin for the ansible user on the remote machine
* use docker compose to orchestrate the creation of the container image and deployment of the container
