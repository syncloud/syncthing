local name = "syncthing";
local browser = "firefox";
local version = "1.19.0";

local build(arch, test_ui) = [{
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
            image: "debian:buster-slim",
            commands: [
                "echo $DRONE_BUILD_NUMBER > version",
                "echo " + arch + "$DRONE_BRANCH > domain"
            ]
        },
        {
            name: "build python",
            image: "debian:buster-slim",
            commands: [
                "./python/build.sh"
            ],
            volumes: [
                {
                    name: "docker",
                    path: "/usr/bin/docker"
                },
                {
                    name: "docker.sock",
                    path: "/var/run/docker.sock"
                }
            ]
        },
        {
            name: "download",
            image: "debian:buster-slim",
            commands: [
                "./download.sh " + version
            ]
        },
        {
            name: "build",
            image: "golang:1.17.3",
            commands: [
                "./build.sh " + version
            ]
        },
        {
            name: "package",
            image: "debian:buster-slim",
            commands: [
                "VERSION=$(cat version)",
                "./package.sh " + name + " $VERSION " + arch
            ]
        },
        {
            name: "test-integration",
            image: "python:3.8-slim-buster",
            commands: [
              "apt-get update && apt-get install -y sshpass openssh-client netcat rustc file libxml2-dev libxslt-dev build-essential libz-dev curl",
              "APP_ARCHIVE_PATH=$(realpath $(cat package.name))",
              "cd integration",
              "pip install -r requirements.txt",
              "py.test -x -s verify.py --domain=buster.com --app-archive-path=$APP_ARCHIVE_PATH --device-host=" + name + ".buster.com --app=" + name
            ]
        }] + ( if test_ui then [
        {
            name: "test-ui-desktop",
            image: "python:3.8-slim-buster",
            commands: [
              "apt-get update && apt-get install -y sshpass openssh-client",
              "cd integration",
              "pip install -r requirements.txt",
              "py.test -x -s test-ui.py --ui-mode=desktop --domain=buster.com --device-host=" + name + ".buster.com --app=" + name + " --browser=" + browser,
            ],
            volumes: [{
                name: "shm",
                path: "/dev/shm"
            }]
        },
        {
            name: "test-ui-mobile",
            image: "python:3.8-slim-buster",
            commands: [
              "apt-get update && apt-get install -y sshpass openssh-client",
              "cd integration",
              "pip install -r requirements.txt",
              "py.test -x -s test-ui.py --ui-mode=mobile --domain=buster.com --device-host=" + name + ".buster.com --app=" + name + " --browser=" + browser,
            ],
            volumes: [{
                name: "shm",
                path: "/dev/shm"
            }]
        }] else [] ) + [
        {
            name: "upload",
            image: "debian:buster-slim",
            environment: {
                AWS_ACCESS_KEY_ID: {
                    from_secret: "AWS_ACCESS_KEY_ID"
                },
                AWS_SECRET_ACCESS_KEY: {
                     from_secret: "AWS_SECRET_ACCESS_KEY"
                }
            },
            commands: [
              "PACKAGE=$(cat package.name)",
               "apt update && apt install -y wget",
               "wget https://github.com/syncloud/snapd/releases/download/1/syncloud-release-" + arch,
               "chmod +x syncloud-release-*",
               "./syncloud-release-* publish -f $PACKAGE -b $DRONE_BRANCH"
             ],
            when: {
                branch: ["stable", "master"]
            }
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
            name: name + ".buster.com",
            image: "syncloud/platform-buster-" + arch + ":21.10",
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
    ] + if test_ui then [{
            name: "selenium",
            image: "selenium/standalone-" + browser + ":4.0.0-beta-3-prerelease-20210402",
            volumes: [{
                name: "shm",
                path: "/dev/shm"
            }]
        }] else [],
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
        },
        {
            name: "docker",
            host: {
                path: "/usr/bin/docker"
            }
        },
        {
            name: "docker.sock",
            host: {
                path: "/var/run/docker.sock"
            }
        }
    ]
},
{
    kind: "pipeline",
    type: "docker",
    name: "promote-" + arch,
    platform: {
      os: "linux",
      arch: arch
    },
    steps: [
    {
          name: "promote",
          image: "debian:buster-slim",
          environment: {
              AWS_ACCESS_KEY_ID: {
                  from_secret: "AWS_ACCESS_KEY_ID"
              },
              AWS_SECRET_ACCESS_KEY: {
                  from_secret: "AWS_SECRET_ACCESS_KEY"
              }
          },
          commands: [
            "apt update && apt install -y wget",
            "wget https://github.com/syncloud/snapd/releases/download/1/syncloud-release-" + arch + " -O release --progress=dot:giga",
            "chmod +x release",
            "./release promote -n " + name + " -a $(dpkg --print-architecture)"
          ]
    }
    ],
    trigger: {
        event: [
          "promote"
        ]
    }
}];


build("amd64", true) +
build("arm", false) +
build("arm64", false)
