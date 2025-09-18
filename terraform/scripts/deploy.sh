#!/bin/bash

set -e

# Переменные
VM_IP=$(terraform output -raw vm_public_ip)
SSH_USER=$(terraform output -raw vm_username)
SSH_KEY="~/.ssh/id_ed25519"

echo "Waiting for VM to be ready..."
sleep 30

# Функция для проверки доступности ВМ
wait_for_vm() {
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ssh -i $SSH_KEY -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SSH_USER@$VM_IP "exit 0"; then
            echo "VM is ready!"
            return 0
        fi
        echo "Attempt $attempt: VM not ready yet, waiting..."
        sleep 30
        attempt=$((attempt + 1))
    done
    
    echo "VM failed to become ready after $max_attempts attempts"
    return 1
}

wait_for_vm

echo "Deploying to VM at $VM_IP..."

# Копируем обновленный docker-compose.yml
scp -i $SSH_KEY -o StrictHostKeyChecking=no ./docker-compose.yml $SSH_USER@$VM_IP:~/app/docker-compose.yml

# Останавливаем текущие контейнеры
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$VM_IP "cd ~/app && docker-compose down || true"

# Перезапускаем контейнеры
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$VM_IP "cd ~/app && docker-compose up -d --build"

echo "Deployment completed successfully!"
echo "Application URL: http://$VM_IP"