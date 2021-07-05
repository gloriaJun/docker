#### Run Docker Container

```bash
docker-compose up -d
```

##### Stop

```bash
docker container stop jenkins-master
docker container stop nginx
```

#### Process check

```bash
docker ps -a
```

#### Logs

`docker container logs <container_name>`

```bash
docker container logs jenkins-master
docker container logs nginx
```

#### access to container

```bash
docker container exec -it jenkins-master /bin/bash
```
