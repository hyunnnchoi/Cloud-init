terraform {
  required_providers {
    lambdalabs = {
      source = "elct9620/lambdalabs"
    }
  }
}

provider "lambdalabs" {
  # Set via environment variable: export LAMBDALABS_API_KEY="your_api_key"
  # Or uncomment and set directly:
  # api_key = "your_api_key_here"
}

# SSH Key resource (create once, reuse)
resource "lambdalabs_ssh_key" "cluster_key" {
  name       = "k8s-cluster-key"
  public_key = file("~/.ssh/id_rsa.pub") # Adjust path as needed
}

# Master Node
resource "lambdalabs_instance" "master" {
  region_name       = "us-tx-1"  # Texas region
  instance_type_name = "gpu_8x_v100"  # 8x Tesla V100
  ssh_key_names     = [lambdalabs_ssh_key.cluster_key.name]
  
  # Upload your setup script to the instance
  provisioner "file" {
    source      = "./setup-c1.sh"
    destination = "/tmp/setup-c1.sh"
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.ip
      timeout     = "10m"
    }
  }

  # Make script executable and run master setup
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup-c1.sh",
      "sudo /tmp/setup-c1.sh master > /tmp/master_setup.log 2>&1",
      "echo 'Master node setup completed. Check /tmp/master_setup.log for details.'"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.ip
      timeout     = "60m"  # Your script takes a while to complete
    }
  }

  # Extract join command for worker node
  provisioner "remote-exec" {
    inline = [
      "if [ -f /home/ubuntu/worker_join_command.txt ]; then cat /home/ubuntu/worker_join_command.txt; fi"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.ip
    }
  }

  tags = {
    Name = "k8s-master"
    Role = "master"
  }
}

# Worker Node
resource "lambdalabs_instance" "worker" {
  region_name       = "us-tx-1"  # Same region as master
  instance_type_name = "gpu_8x_v100"  # 8x Tesla V100
  ssh_key_names     = [lambdalabs_ssh_key.cluster_key.name]
  
  # Wait for master to be ready
  depends_on = [lambdalabs_instance.master]

  # Upload your setup script to the instance
  provisioner "file" {
    source      = "./setup-c1.sh"
    destination = "/tmp/setup-c1.sh"
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.ip
      timeout     = "10m"
    }
  }

  # Run worker setup
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup-c1.sh",
      "sudo /tmp/setup-c1.sh worker > /tmp/worker_setup.log 2>&1",
      "echo 'Worker node setup completed. Check /tmp/worker_setup.log for details.'"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.ip
      timeout     = "60m"
    }
  }

  # Join the cluster (you'll need to extract join command from master)
  provisioner "remote-exec" {
    inline = [
      "# You'll need to modify this to use the actual join command from master",
      "# For now, this is a placeholder - see the note below about getting join command",
      "echo 'Ready to join cluster. Manual join command execution required.'"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.ip
    }
  }

  tags = {
    Name = "k8s-worker"
    Role = "worker"
  }
}

# Output important information
output "master_ip" {
  value = lambdalabs_instance.master.ip
  description = "Master node IP address"
}

output "worker_ip" {
  value = lambdalabs_instance.worker.ip
  description = "Worker node IP address"
}

output "ssh_commands" {
  value = {
    master = "ssh -i ~/.ssh/id_rsa ubuntu@${lambdalabs_instance.master.ip}"
    worker = "ssh -i ~/.ssh/id_rsa ubuntu@${lambdalabs_instance.worker.ip}"
  }
  description = "SSH commands to connect to the instances"
}

# Data source to get join command from master (advanced approach)
# This is a more sophisticated approach using null_resource
resource "null_resource" "get_join_command" {
  depends_on = [lambdalabs_instance.master]
  
  provisioner "local-exec" {
    command = <<-EOT
      ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@${lambdalabs_instance.master.ip} \
      'cat /home/ubuntu/worker_join_command.txt 2>/dev/null || echo "Join command not found"' > join_command.txt
    EOT
  }
}

# Execute join command on worker
resource "null_resource" "join_worker" {
  depends_on = [
    lambdalabs_instance.worker,
    null_resource.get_join_command
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      JOIN_CMD=$(cat join_command.txt)
      if [[ "$JOIN_CMD" != "Join command not found" ]]; then
        ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@${lambdalabs_instance.worker.ip} \
        "echo '$JOIN_CMD' | sudo bash"
      else
        echo "Warning: Join command not available. Manual join required."
      fi
    EOT
  }
}