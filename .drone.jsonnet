local name = "syncthing";
local browser = "firefox";
local version = "1.19.0";

local build(arch) = {
    kind: "pipeline",
    type: "docker",
    name: arch,
    platform: {
        os: "linux",
        arch: arch
    },
    steps: [
        {
            name: "version",
            image: "syncloud/build-deps-" + arch + ":2021.4.1",
            commands: [
                "echo $(date +%y%m%d)$DRONE_BUILD_NUMBER > version",
                "echo " + arch + "$DRONE_BRANCH > domain"
            ]
        },
        {
            name: "download",
            image: "syncloud/build-deps-" + arch + ":2021.4.1",
            commands: [
                "./download.sh " + version
            ]
        },
        {
            name: "build",
            image: "golang:1.14",
            commands: [
                "./build.sh " + version
            ]
        },
        {
            name: "package",
            image: "syncloud/build-deps-" + arch + ":2021.4.1",
            commands: [
                "VERSION=$(cat version)",
                "./package.sh " + name + " $VERSION"
            ]
        },
        {
            name: "test-integration",
            image: "python:3.9-buster",
            commands: [
              "apt-get update && apt-get install -y sshpass openssh-client netcat rustc",
              "pip install -r dev_requirements.txt",
              "APP_ARCHIVE_PATH=$(realpath $(cat package.name))",
              "DOMAIN=$(cat domain)",
              "cd integration",
              "py.test -x -s verify.py --domain=$DOMAIN --app-archive-path=$APP_ARCHIVE_PATH --device-host=device --app=" + name
            ]
        }] + ( if arch == "arm" then [] else [
        {
            name: "test-ui-desktop",
            image: "python:3.9-buster",
            commands: [
              "apt-get update && apt-get install -y sshpass openssh-client",
              "pip install -r dev_requirements.txt",
              "DOMAIN=$(cat domain)",
              "cd integration",
              "py.test -x -s test-ui.py --ui-mode=desktop --domain=$DOMAIN --device-host=device --app=" + name + " --browser=" + browser,
            ],
            volumes: [{
                name: "shm",
                path: "/dev/shm"
            }]
        },
        {
            name: "test-ui-mobile",
            image: "python:3.9-buster",
            commands: [
              "apt-get update && apt-get install -y sshpass openssh-client",
              "pip install -r dev_requirements.txt",
              "DOMAIN=$(cat domain)",
              "cd integration",
              "py.test -x -s test-ui.py --ui-mode=mobile --domain=$DOMAIN --device-host=device --app=" + name + " --browser=" + browser,
            ],
            volumes: [{
                name: "shm",
                path: "/dev/shm"
            }]
        }]) + [
        {
            name: "upload",
            image: "python:3.9-buster",
            environment: {
                AWS_ACCESS_KEY_ID: {
                    from_secret: "AWS_ACCESS_KEY_ID"
                },
                AWS_SECRET_ACCESS_KEY: {
                    from_secret: "AWS_SECRET_ACCESS_KEY"
                }
            },
            commands: [
              "VERSION=$(cat version)",
              "PACKAGE=$(cat package.name)",
              "pip install syncloud-lib s3cmd",
              "syncloud-upload.sh " + name + " $DRONE_BRANCH $VERSION $PACKAGE"
            ]
        },
        {
            name: "artifact",
            image: "appleboy/drone-scp:1.6.2",
            settings: {
                host: {
                    from_secret: "artifact_host"
                },
                username: "artifact",
                key: {
                    from_secret: "artifact_key"
                },
                timeout: "2m",
                command_timeout: "2m",
                target: "/home/artifact/repo/" + name + "/${DRONE_BUILD_NUMBER}-" + arch,
                source: "artifact/*",
		             strip_components: 1
            },
            when: {
              status: [ "failure", "success" ]
            }
        }
    ],
    services: [
        {
            name: "device",
            image: "syncloud/systemd-" + arch,
            privileged: true,
            volumes: [
                {
                    name: "dbus",
                    path: "/var/run/dbus"
                },
                {
                    name: "dev",
                    path: "/dev"
                }
            ]
        }
    ] + if arch == "arm" then [] else [{
            name: "selenium",
            image: "selenium/standalone-" + browser + ":4.0.0-beta-3-prerelease-20210402",
            volumes: [{
                name: "shm",
                path: "/dev/shm"
            }]
        }],
    volumes: [
        {
            name: "dbus",
            host: {
                path: "/var/run/dbus"
            }
        },
        {
            name: "dev",
            host: {
                path: "/dev"
            }
        },
        {
            name: "shm",
            temp: {}
        }
    ]
};


[
    build("arm"),
    build("amd64")
]
