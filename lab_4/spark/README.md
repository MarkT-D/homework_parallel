# Spark Docker Setup

## Commands

Start cluster:
```bash
docker compose up -d
```

Stop cluster:
```bash
docker compose down
```

Check containers:
```bash
docker ps
```

Spark UI:

Master: http://localhost:8080


Add and commit:

```bash
cd ..   # back to lab4 root
git add spark/docker-compose.yml spark/README.md
git commit -m "Add Spark Docker setup"
```