#!/bin/bash

# Кольори для банера
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m' # Без кольору

# Банер
echo -e "${YELLOW}====================================================${NC}"
echo -e "${GREEN}=           🚀 Nexus Node Setup                   =${NC}"
echo -e "${YELLOW}=                CPI.TM                          =${NC}"
echo -e "${GREEN}=              by billymoor                       =${NC}"
echo -e "${YELLOW}====================================================${NC}\n"

# Оновлюємо пакети та встановлюємо залежності для Docker
echo "Оновлюємо пакети та встановлюємо залежності для Docker..."
sudo apt update
sudo apt install -y curl ca-certificates apt-transport-https gnupg lsb-release wget jq

# Додаємо GPG-ключ Docker
echo "Додаємо GPG-ключ Docker..."
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Додаємо репозиторій Docker
echo "Додаємо репозиторій Docker..."
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Встановлюємо Docker
echo "Встановлюємо Docker..."
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Перевіряємо версію Docker
echo "Перевіряємо версію Docker..."
docker --version

# Встановлюємо Docker Compose
echo "Встановлюємо Docker Compose..."
COMPOSE_VER=$(wget -qO- https://api.github.com/repos/docker/compose/releases/latest | jq -r ".tag_name")
sudo wget -O /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)"
sudo chmod +x /usr/local/bin/docker-compose

# Перевіряємо версію Docker Compose
echo "Перевіряємо версію Docker Compose..."
docker-compose --version

# Встановлюємо Screen
echo "Встановлюємо Screen..."
sudo apt install -y screen

# Скачуємо образ
echo "Скачуємо образ Docker..."
docker pull nexusxyz/nexus-cli:latest

# Створюємо сесію screen
echo "Створюємо сесію screen..."
screen -S nexus3

# Повідомлення про завершення
echo "Встановлення завершено! Тепер ви в сесії screen із Nexus CLI."

# Останнє повідомлення
echo -e "${GREEN}Запускаємо ноду командою нижче, але змінюємо на свій ID:${NC}"
echo "docker run -it --init --name nexus nexusxyz/nexus-cli:latest start --node-id ВАШ_ID"
