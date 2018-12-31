# --------------------------------
# Data
# --------------------------------

data "vsphere_datacenter" "dc" {
    name = "${var.vm_datacenter}"
}

data "vsphere_datastore" "datastore" {
    name          = "${var.vm_datastore}"
    datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
    name          = "${var.vm_template}"
    datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
    name          = "${var.vm_network}"
    datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
    name            = "${var.vm_resource_pool}"
    datacenter_id   = "${data.vsphere_datacenter.dc.id}" 
}


# --------------------------------
# Resources
# --------------------------------

# Linux VM with Static IP

resource "vsphere_virtual_machine" "linux-vm" {
    # VM placement #
    name             = "${var.vm_name}"
    folder           = "${var.vm_folder}"
    resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
    datastore_id     = "${data.vsphere_datastore.datastore.id}"

    num_cpus    = "${var.vm_vcpu_number}"
    memory      = "${var.vm_memory_size}"
    scsi_type   = "${var.vm_scsi_type}"
    
    # Guest OS #
    guest_id    = "${data.vsphere_virtual_machine.template.guest_id}"

    # VM storage #
    disk {
        label            = "${var.vm_name}.vmdk"
        size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
        thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
        eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    }

    # VM networking #
    network_interface {
        network_id   = "${data.vsphere_network.network.id}"
        adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
    }

    # Customization of the VM #
    clone {
        template_uuid = "${data.vsphere_virtual_machine.template.id}"
    }
    
    wait_for_guest_net_routable = false
    
    # Upload script
    provisioner "file" {
 	connection {
		type	    = "ssh"
		insecure    = true
		user	    = "${var.vm_user}"
		password    = "${var.vm_password}"
	}
    
	source      = "${var.vm_customization_script}"
	destination = "/tmp/${var.vm_customization_script}"
   }
    
    # execute the script	
    provisioner "remote-exec" {
	connection {
		type	    = "ssh"
		insecure    = true
		user	    = "${var.vm_user}"
		password    = "${var.vm_password}"
	}
    
	inline = [
	    # make script executable
            "chmod +x /tmp/${var.vm_customization_script}",			
           
	    # execute script as sudo		
       	    "echo ${var.vm_password} | sudo -S /bin/bash /tmp/${var.vm_customization_script} --ip_address ${var.vm_ip} --dns1 ${ element( split(",", var.vm_dns_servers), 0) } --dns2 ${ element( split(",", var.vm_dns_servers), 1) } --domain ${var.vm_domain} --hostname ${var.vm_name} --netmask ${var.vm_netmask} --gateway ${var.vm_gateway}"
	]
    }
}

