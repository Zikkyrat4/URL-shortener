terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.104.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = var.yandex_token
  cloud_id  = var.yandex_cloud_id
  folder_id = var.yandex_folder_id
  zone      = "ru-central1-a"
}

# Создание сети
resource "yandex_vpc_network" "url-shortener-network" {
  name = "url-shortener-network"
}

resource "yandex_vpc_subnet" "url-shortener-subnet" {
  name           = "url-shortener-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.url-shortener-network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# Группа безопасности
resource "yandex_vpc_security_group" "url-shortener-sg" {
  name        = "url-shortener-security-group"
  description = "Security group for URL shortener application"
  network_id  = yandex_vpc_network.url-shortener-network.id

  ingress {
    description    = "HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Application port"
    protocol       = "TCP"
    port           = 8080
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Outbound traffic"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Управляемая PostgreSQL
resource "yandex_mdb_postgresql_cluster" "url-shortener-db" {
  name        = "url-shortener-db"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.url-shortener-network.id

  config {
    version = 15
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 10
    }

    postgresql_config = {
      max_connections                   = 100
      enable_parallel_hash              = true
      autovacuum_vacuum_scale_factor    = 0.34
      default_transaction_isolation     = "TRANSACTION_ISOLATION_READ_COMMITTED"
      shared_preload_libraries          = "SHARED_PRELOAD_LIBRARIES_AUTO_EXPLAIN,SHARED_PRELOAD_LIBRARIES_PG_HINT_PLAN"
    }
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.url-shortener-subnet.id
  }
}

resource "yandex_mdb_postgresql_user" "db_user" {
  cluster_id = yandex_mdb_postgresql_cluster.url-shortener-db.id
  name       = var.db_username
  password   = var.db_password
  conn_limit = 50
  login      = true
}

resource "yandex_mdb_postgresql_database" "urlshortener" {
  cluster_id = yandex_mdb_postgresql_cluster.url-shortener-db.id
  name       = "urlshortener"
  owner      = yandex_mdb_postgresql_user.db_user.name

  depends_on = [yandex_mdb_postgresql_user.db_user]
}

# Виртуальная машина
resource "yandex_compute_instance" "url-shortener-vm" {
  name        = "url-shortener-vm"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd8vmcue7aajpmeo39kk" # Ubuntu 22.04
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.url-shortener-subnet.id
    nat       = true
    security_group_ids = [yandex_vpc_security_group.url-shortener-sg.id]
  }

  metadata = {
    ssh-keys = "${var.vm_username}:${var.ssh_public_key}"
    user-data = <<-EOF
      #cloud-config
      packages:
        - docker.io
        - curl
        - nginx
      runcmd:
        - systemctl enable docker
        - systemctl start docker
        # Добавляем пользователя в группу docker и перезагружаем групповые права
        - usermod -aG docker ${var.vm_username}
        - newgrp docker
        # Установка Docker Compose v2
        - mkdir -p /usr/local/lib/docker/cli-plugins
        - curl -SL https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
        - chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
        - ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
        # Даем права на docker socket
        - chmod 666 /var/run/docker.sock
      EOF
  }
}


# Отдельный ресурс для provisioning
resource "null_resource" "provision_vm" {
  depends_on = [
    yandex_compute_instance.url-shortener-vm,
    yandex_mdb_postgresql_cluster.url-shortener-db,
    yandex_mdb_postgresql_database.urlshortener
  ]

  connection {
    type        = "ssh"
    user        = var.vm_username
    private_key = file("~/.ssh/id_ed25519_terraform")
    host        = yandex_compute_instance.url-shortener-vm.network_interface[0].nat_ip_address
    timeout     = "15m"
  }

  provisioner "file" {
    source      = "templates/nginx.conf.tpl"
    destination = "/tmp/nginx.conf"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/docker-compose.yml.tpl", {
      db_host     = yandex_mdb_postgresql_cluster.url-shortener-db.host[0].fqdn
      db_port     = 6432
      db_name     = yandex_mdb_postgresql_database.urlshortener.name
      db_user     = var.db_username
      db_password = var.db_password
      vm_ip       = yandex_compute_instance.url-shortener-vm.network_interface[0].nat_ip_address
    })
    destination = "/tmp/docker-compose.yml"
  }

  # Копируем только нужные файлы по отдельности
  provisioner "file" {
    source      = "../Dockerfile"
    destination = "/tmp/Dockerfile"
  }

  provisioner "file" {
    source      = "../go.mod"
    destination = "/tmp/go.mod"
  }

  provisioner "file" {
    source      = "../go.sum"
    destination = "/tmp/go.sum"
  }

  provisioner "file" {
    source      = "../cmd/server/"
    destination = "/tmp/cmd/server/"
  }

  provisioner "file" {
    source      = "../internal/"
    destination = "/tmp/internal/"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Waiting for Docker to start...'",
      "until systemctl is-active --quiet docker; do sleep 10; echo 'Docker not ready yet...'; done",
      
      "echo 'Setting up Nginx...'",
      "sudo mkdir -p /etc/nginx/sites-available",
      "sudo mkdir -p /etc/nginx/sites-enabled",
      "sudo mv /tmp/nginx.conf /etc/nginx/sites-available/url-shortener",
      "sudo ln -sf /etc/nginx/sites-available/url-shortener /etc/nginx/sites-enabled/",
      "sudo rm -f /etc/nginx/sites-enabled/default",
      "sudo systemctl restart nginx",
      
      "echo 'Setting up application...'",
      "mkdir -p ~/app",
      "mv /tmp/docker-compose.yml ~/app/docker-compose.yml",
      "mv /tmp/Dockerfile ~/app/Dockerfile",
      "mv /tmp/go.mod ~/app/go.mod",
      "mv /tmp/go.sum ~/app/go.sum",
      "mkdir -p ~/app/cmd/server",
      "mv /tmp/cmd/server/* ~/app/cmd/server/",
      "mkdir -p ~/app/internal",
      "mv /tmp/internal ~/app/",
      
      "echo 'Starting containers...'",
      "cd ~/app && sudo docker-compose up -d --build"
    ]
  }
}