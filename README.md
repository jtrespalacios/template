# Vapor Template

This template serves as a starting point for a Vapor 3 project. You can start a
new project by running:

    vapor new ProjectName --template=jtrespalacios/template

## Docker Environment (Optional)

[Install Docker](https://docs.docker.com/docker-for-mac/install/)
[Install VirtualBox](https://www.virtualbox.org/wiki/Downloads)

### Setup Docker Machine (Optional for Docker)

Using Docker Machine can be useful if you have various environments to work
with, this is an optional step in the process.  The `docker-machine` command
should have been installed with Docker.  To create a new Docker Host run the
following command.

```bash
docker-machine create --driver virtualbox default
```

This will create a new Docker Host named `default` using VirtualBox.  This
command may take sometime to complete.  Once it has completed you will need to
run `eval $(docker-machine env default)` to load the machines configuration.

### Build and Launch the application

Now that your host is ready its time to build the application environment.
This is done by running the command `docker-compose build`. This will fetch the
containers and prepare them for use. Finally run `docker-compose up` to launch
the environment. As currently configure the application is not built and
launched when the docker envioronment is brought up.

If you have setup a Docker Machine then you will need to first attach to
the host by running `docker-machine ssh`, you will now at a shell inside of the
docker host.

From here run `docker ps`.  The list of containers currently running on the host
(either the `docker-machine` or your machine) will be listed.  Look for a
container an image named `api:dev` and a name ending in `_api_1`, this will be
the container to connect to.  To do so run `docker attach CONTAINER_NAME_HERE`.

Now you will need to build and run the application and it will be available from
your host through the `docker-machine` vm.  First run `swift build`.  Once this
has completed and the application has been complied run
`swift run Run --hostname 0.0.0.0`.  The hostname is important as this is the
address that is exposed to the dockerhost. If the hostname parameter is ommited
the application gets bound to localhost and is only able to accept requests from
the container itself.

### Developing the application

#### Server Application

Having the docker environment setup on your localhost is useful and lets you see
a replica of the applicationas deployed it is easier to use xcode and run
directly on your machine.  To do so you will need to install redis and mysql on
your local host and create the necessary database in MySql for the application
to use.

To generate an xcode project run `vapor xcode` in termal inside of your working
directory.  Once this has completed you will be able to use XCode to run the
application and debug as you would a Mac or iOS application.  To run the
application make sure you have selected the `Run` target.

