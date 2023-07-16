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
docker run -it --gpus all -p 9600:9600 -v /models:/models -v ./help:/lollms-webui/help -v ./data:/lollms-webui/data -v ./data/.parisneo:/root/.parisneo/ -v ./configs:/lollms-webui/configs -v ./web:/lollms-webui/web lollms-webui-docker:latest python3 app.py --host 0.0.0.0 --port 9600 --db_path data/database.db
```

Note: -it is needed to trick Werkzeug into think it's not a production server (which is fine if you're not deploying this, as you shouldn't be...)

# Running pre-built image

Pre-built images are provided at https://hub.docker.com/r/noneabove1182/lollms-webui

Follow the same command as above except with noneabove1182/lollms-webui:(version)

# Running with docker compose

A docker-compose.yaml file has been provided, as well as a .env file that I use for setting my model dir and the model name I'd like to load in with

Feel free to modify both to fit your needs

# Quirks and features

The default config file provided has been modified to automatically load c_transformers, this is simply because it needs SOMETHING selected to get the webserver to launch, you can then go in there and change to whatever you'd like. For some reason not specifying a valid model does not block this, so it's just been set to CHANGEME (which you can change or leave as is and load from the webui)

tty/stdin_open are needed in order to trick Werkzeug, without standard input open it will assume you're running a production server, and since I don't feel like changing the base code from ParisNeo I've simply tricked it into not realizing it's in a docker container
