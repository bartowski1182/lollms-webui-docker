# lollms-webui-docker

Docker images and configuration to run lollms-webui with GPU, currently updated to release v3.0 found here: https://github.com/ParisNeo/lollms-webui/releases/tag/v3.0

# Build instructions

First checkout this branch

```sh
git clone https://github.com/noneabove1182/lollms-webui-docker.git
```

Next, build the image

```sh
cd lollms-webui-docker
docker build -t lollms-webui-docker:latest .
```

Now run the image

```sh
docker run --gpus all -p 7860:7860 -v /models:/models -v ./help:/lollms-webui/help -v ./data:/lollms-webui/data -v ./data/.parisneo:/root/.parisneo/ -v ./configs:/lollms-webui/configs -v ./web:/lollms-webui/web lollms-webui-docker:latest python3 app.py --host 0.0.0.0 --port 9600 --db_path data/database.db
```

# Running pre-built image

Pre-built images are provided at https://hub.docker.com/r/noneabove1182/text-gen-ui-gpu

Follow the same command as above except with noneabove1182/text-gen-ui-gpu:(version)

# Running with docker compose

A docker-compose.yaml file has been provided, as well as a .env file that I use for setting my model dir and the model name I'd like to load in with

Feel free to modify both to fit your needs, for example I prefer --no-stream but if you don't you can remove it
