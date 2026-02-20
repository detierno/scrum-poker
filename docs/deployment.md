# Deploying Planning Poker to AWS with Kamal

Deploy to a single AWS EC2 instance **without a domain**: use the instance’s public IP (e.g. `http://3.14.159.26`).

## Prerequisites

- Docker installed locally (for building the image)
- An AWS EC2 instance (Ubuntu 22.04 recommended)
- Docker Hub account (or AWS ECR)
- **No domain required**

## 1. Create an EC2 instance

1. In AWS EC2, launch an instance:
   - **AMI**: Ubuntu Server 22.04 LTS
   - **Instance type**: e.g. t3.small (1 vCPU, 2 GB RAM)
   - **Security group**: allow inbound **22** (SSH), **80** (HTTP)
   - **Key pair**: create or select one for SSH
   - **Storage**: 8 GB is enough

2. Note the **public IP** (e.g. `3.14.159.26`). The app will be at `http://3.14.159.26`.

## 2. Prepare the server

SSH into the instance:

```bash
ssh -i your-key.pem ubuntu@YOUR_EC2_IP
```

Install Docker on Ubuntu:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
exit
```

Log in again so the `docker` group applies.

## 3. Configure Kamal (no domain)

Edit `config/deploy.yml`:

1. **servers.web.hosts** – your EC2 public IP:
   ```yaml
   servers:
     web:
       hosts:
         - 3.14.159.26
   ```

2. **env.clear.RAILS_HOST** – same IP (for share links):
   ```yaml
   env:
     clear:
       REDIS_URL: redis://poker-redis:6379/1
       RAILS_HOST: 3.14.159.26
   ```

3. **image** and **registry.username** – your Docker Hub (or ECR) image and username.

4. **ssh.user** – `ubuntu` for Ubuntu AMI, or `ec2-user` for Amazon Linux.

5. **ssh.keys** – path to your EC2 key pair `.pem` file so Kamal can SSH into the instance:
   ```yaml
   ssh:
     user: ubuntu
     keys:
       - ~/.ssh/your-key.pem
   ```
   Use the same key you use for `ssh -i your-key.pem ubuntu@YOUR_EC2_IP`. The path can be `~/.ssh/your-key.pem` or an absolute path (e.g. `/Users/you/keys/ec2.pem`).

Leave **proxy** disabled (no `proxy:` section, or comment it out). The config uses `proxy: false` so the app is served on port 80 directly (no Traefik, no SSL).

## 4. Set secrets

In `.kamal/secrets` you need:

- `KAMAL_REGISTRY_PASSWORD` – Docker Hub token or ECR password
- `RAILS_MASTER_KEY` – from `config/master.key`

Example (do not commit real values):

```bash
export KAMAL_REGISTRY_PASSWORD=your-dockerhub-token
# RAILS_MASTER_KEY is read from config/master.key in .kamal/secrets
```

## 5. Deploy

First time:

```bash
# Boot Redis (same host as web)
bin/kamal accessory boot redis

# Deploy the app
bin/kamal deploy
```

Then open **http://YOUR_EC2_IP** in a browser. Share links will look like `http://YOUR_EC2_IP/rooms/join?code=ABC123`.

Subsequent deploys:

```bash
bin/kamal deploy
```

## 6. Using AWS ECR instead of Docker Hub

1. Create an ECR repository (e.g. `poker`).
2. In `config/deploy.yml`:
   ```yaml
   image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/poker
   registry:
     server: 123456789012.dkr.ecr.us-east-1.amazonaws.com
     username: AWS
     password:
       - KAMAL_REGISTRY_PASSWORD
   ```
3. Before deploy: `export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region us-east-1)`

## 7. Useful commands

```bash
bin/kamal app logs -f
bin/kamal app exec -i "bin/rails console"
bin/kamal accessory reboot redis
bin/kamal remove -y
```

## 8. Troubleshooting

- **Authentication failed for user ubuntu@…**: Kamal must use your EC2 private key. In `config/deploy.yml` set `ssh.keys` to the path of your `.pem` file (e.g. `~/.ssh/your-key.pem`). Ensure the key has correct permissions: `chmod 600 your-key.pem`. Test with `ssh -i your-key.pem ubuntu@YOUR_EC2_IP`.

- **Bind for 0.0.0.0:80 failed: port is already allocated**: Port 80 is in use.

  **Quick fix (from your machine):** Remove existing app containers and proxy, then redeploy:
  ```bash
  bin/kamal remove -y
  bin/kamal accessory boot redis    # if Redis was removed
  bin/kamal deploy
  ```

  **If that doesn’t help**, free port 80 on the server:

  1. SSH in: `ssh -i your-key.pem ubuntu@YOUR_EC2_IP`
  2. See what is using port 80:
     ```bash
     sudo ss -tlnp | grep :80
     # or
     sudo lsof -i :80
     ```
  3. If it’s an old Docker container:
     ```bash
     sudo docker ps -a
     sudo docker stop $(sudo docker ps -aq --filter "name=poker")   # stop poker containers
     sudo docker rm $(sudo docker ps -aq --filter "name=poker")     # remove them
     ```
     Or remove all stopped containers: `sudo docker container prune -f`
  4. If it’s Kamal proxy (Traefik): from your **local** machine run `bin/kamal proxy remove`, then redeploy.
  5. If it’s nginx/apache: `sudo systemctl stop nginx` or `sudo systemctl stop apache2` (or disable if you don’t need it).

  Then run `bin/kamal deploy` again.

- **Can’t reach http://IP**: Security group must allow inbound **80**. App listens on port 80 (no proxy).
- **502 / connection refused**: App may still be starting. Check `bin/kamal app logs`.
- **Can’t connect to Redis**: Run `bin/kamal accessory boot redis` and keep `REDIS_URL: redis://poker-redis:6379/1` in `config/deploy.yml`.
- **Share link wrong**: Set `RAILS_HOST` in `config/deploy.yml` to your EC2 public IP.

## 9. Optional: Deploy with a domain and HTTPS

If you later add a domain:

1. Point the domain’s A record to your EC2 IP.
2. In `config/deploy.yml`:
   - Remove or change the web role so the proxy is used:
     ```yaml
     servers:
       web:
         hosts:
           - 3.14.159.26
     # remove: proxy: false and options.publish
     ```
   - Add (or uncomment) proxy and set your domain:
     ```yaml
     proxy:
       ssl: true
       host: poker.yourdomain.com
     ```
   - Set `RAILS_HOST: poker.yourdomain.com` in `env.clear`.
3. Open **443** in the EC2 security group.
4. Run `bin/kamal deploy`. Let’s Encrypt will issue a certificate for your domain.

## Architecture (no domain)

- **poker** container listens on port 80 and is published to host port 80 (no Traefik).
- **poker-redis** runs on the same host for Action Cable.
- Access: `http://EC2_IP`. Share links: `http://EC2_IP/rooms/join?code=...`.
- No database; rooms are in memory (single instance).
