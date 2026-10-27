FROM ubuntu:20.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Update and install packages
RUN apt-get update && apt-get install -y \
    openssh-server \
    apache2 \
    php \
    libapache2-mod-php \
    php-mysql \
    php-mysqli \
    php-mbstring \
    php-json \
    mysql-server \
    python3 \
    python3-pip \
    vim \
    sudo \
    curl \
    wget \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages (add more if your scripts need them)
RUN pip3 install requests selenium beautifulsoup4

# Create Users 
RUN useradd -m -s /bin/bash daniel && \
    echo "daniel:C@ughtm3napping123" | chpasswd && \
    useradd -m -s /bin/bash adrian && \
    echo "adrian:adrian_is_best1442" | chpasswd && \
    groupadd administrators && \
    usermod -aG administrators daniel && \
    usermod -aG administrators adrian

# Configure SSH
RUN mkdir /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Copy entire website directory
RUN rm -rf /var/www/html/*
COPY ./web/ /var/www/html/

# Fix config.php to use 127.0.0.1 instead of localhost (fixes socket permission issues)
RUN sed -i "s/'localhost'/'127.0.0.1'/g" /var/www/html/config.php

# Setting proper ownership
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 755 /var/www/html

# Copying Adrian files
RUN rm -rf /home/adrian/*
COPY ./adrian/ /home/adrian/

# Setting up permissions for Adrian's files
RUN chown adrian:administrators /home/adrian/query.py && \
    chmod 664 /home/adrian/query.py && \
    chown adrian:adrian /home/adrian/site_status.txt && \
    chown adrian:adrian /home/adrian/user.txt && \
    chmod 664 /home/adrian/site_status.txt && \
    chmod 600 /home/adrian/user.txt

# Create adrian's cron job
RUN echo "*/2 * * * * /usr/bin/python3 /home/adrian/query.py" | crontab -u adrian -

# Copying root files
COPY ./root/ /root/

# Setting root directory permissions
RUN chown root:root /root/del_links.py && \
    chown root:root /root/del_users.py && \
    chown root:root /root/nap.py && \
    chown root:root /root/root.txt && \
    chmod 640 /root/del_links.py && \
    chmod 640 /root/del_users.py && \
    chmod 640 /root/nap.py && \
    chmod 600 /root/root.txt

# Setting up root's cron jobs
RUN cat > /tmp/root_cron <<'EOF'
*/5 * * * * /usr/bin/python3 /root/del_links.py
@reboot /usr/bin/python3 /root/del_users.py
*/2 * * * * /usr/bin/python3 /root/nap.py
EOF

RUN crontab /tmp/root_cron && rm /tmp/root_cron

# Configure sudo for adrian (privilege escalation vector)
RUN echo "adrian ALL=(ALL) NOPASSWD: /usr/bin/vim" >> /etc/sudoers

# Apache configuration
RUN a2enmod rewrite

# ========================================
# MYSQL DATABASE SETUP
# ========================================

# Initialize MySQL data directory
RUN mkdir -p /var/run/mysqld && \
    chown -R mysql:mysql /var/run/mysqld && \
    chown -R mysql:mysql /var/lib/mysql

# Configure MySQL to use TCP instead of socket for better compatibility
RUN echo "[mysqld]" > /etc/mysql/mysql.conf.d/docker.cnf && \
    echo "bind-address = 127.0.0.1" >> /etc/mysql/mysql.conf.d/docker.cnf && \
    echo "skip-networking = 0" >> /etc/mysql/mysql.conf.d/docker.cnf

# Start MySQL and create database with tables
RUN service mysql start && \
    mysql -e "CREATE DATABASE IF NOT EXISTS website;" && \
    mysql -e "CREATE USER IF NOT EXISTS 'adrian'@'localhost' IDENTIFIED BY 'P@sswr0d456';" && \
    mysql -e "CREATE USER IF NOT EXISTS 'adrian'@'127.0.0.1' IDENTIFIED BY 'P@sswr0d456';" && \
    mysql -e "GRANT ALL PRIVILEGES ON website.* TO 'adrian'@'localhost';" && \
    mysql -e "GRANT ALL PRIVILEGES ON website.* TO 'adrian'@'127.0.0.1';" && \
    mysql -e "FLUSH PRIVILEGES;" && \
    mysql website -e "CREATE TABLE IF NOT EXISTS links (link VARCHAR(255) NOT NULL);" && \
    mysql website -e "CREATE TABLE IF NOT EXISTS users (id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) NOT NULL UNIQUE, password VARCHAR(255) NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);" && \
    mysql website -e "INSERT INTO users (id, username, password, created_at) VALUES (1, 'hacker', '\$2y\$10\$zBrQrOeQnRqEGa5PwaycXuYlRVE0EB9V/9hNQua3SjjMsrDH8.BXO', '2026-01-13 06:44:31');"

# Create necessary directories & log files
RUN mkdir -p /var/www/html/submissions && \
    touch /var/www/html/submissions/urls.txt && \
    chmod 666 /var/www/html/submissions/urls.txt

# Create log files for cron jobs
RUN touch /var/log/nap.log && \
    touch /var/log/del_links.log && \
    touch /var/log/del_users.log && \
    touch /tmp/query_output.log && \
    chmod 666 /var/log/nap.log /var/log/del_links.log /var/log/del_users.log /tmp/query_output.log

# Startup script
RUN cat > /start.sh <<'STARTEOF'
#!/bin/bash

echo "=========================================="
echo "   Napping CTF Challenge - Starting"
echo "=========================================="
echo ""

# Start MySQL FIRST (very important!)
service mysql start
echo "✓ MySQL Service started"

# Wait for MySQL to be fully ready
sleep 3

# Run del_users.py on startup (equivalent to @reboot)
echo "Running initial cleanup..."
/usr/bin/python3 /root/del_users.py 2>&1

# Start SSH
service ssh start
echo "✓ SSH Service started on port 22"

# Start Apache
service apache2 start
echo "✓ Apache Web Server started on port 80"

# Start Cron
service cron start
echo "✓ Cron service started"

echo ""
echo "=========================================="
echo "   Automation Scripts Active"
echo "=========================================="
echo "Root Cron Jobs:"
echo "  - nap.py (every 2 min) - Admin bot visits URLs"
echo "  - del_links.py (every 5 min) - Cleans old URLs"
echo "  - del_users.py (@reboot) - User cleanup"
echo ""
echo "Adrian Cron Job:"
echo "  - query.py (every 2 min) - Database queries"
echo ""
echo "=========================================="
echo "   Challenge Information"
echo "=========================================="
echo "Web Interface: http://localhost:80"
echo "SSH Access: ssh -p 22 <username>@localhost"
echo "MySQL Database: website (user: adrian)"
echo ""
echo "Credentials (obtained via tab nabbing):"
echo "  daniel:C@ughtm3napping123"
echo ""
echo "Attack Path:"
echo "1. Submit malicious tab nabbing URL via web"
echo "2. nap.py visits your URL (every 2 min)"
echo "3. Capture daniel's credentials via tab nabbing"
echo "4. SSH as daniel"
echo "5. Edit /home/adrian/query.py (group writable)"
echo "6. Add reverse shell to query.py"
echo "7. Wait for cron to execute (every 2 min)"
echo "8. Get adrian shell"
echo "9. Exploit sudo vim to get root"
echo "10. Read /root/root.txt for flag"
echo ""
echo "=========================================="
echo ""

# Keep container running
tail -f /dev/null
STARTEOF

RUN chmod +x /start.sh

# Expose ports
EXPOSE 22 80

CMD ["/start.sh"]