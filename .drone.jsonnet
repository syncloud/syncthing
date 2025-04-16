local name = "syncthing";
local version = "1.29.5";

local browser = "firefox";
local selenium = '4.21.0-20240517';
local platform = '25.02';
local deployer = "https://github.com/syncloud/store/releases/download/4/syncloud-release";
local python = '3.9-slim-buster';
local distro_default = 'buster';
local distros = ['bookworm', 'buster'];

local build(arch, test_ui, dind) = [{
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
            image: "docker:" + dind,
            commands: [
                "./python/build.sh"
            ],
            volumes: [
                {
                    name: "dockersock",
                    path: "/var/run"
                }
            ]
        },
        {
            name: "download",
            image: "debian:buster-slim",
            commands: [
                "./download.sh " + version + " " + arch
            ]
        },
        {
            name: "package",
            image: "debian:buster-slim",
            commands: [
                "VERSION=$(cat version)",
                "./package.sh " + name + " $VERSION"
            ]
        }
        ] + [
           {
             name: 'test ' + distro,
             image: 'python:' + python,
             commands: [
               'APP_ARCHIVE_PATH=$(realpath $(cat package.name))',
               'cd test',
               './deps.sh',
               'py.test -x -s test.py --distro=' + distro + ' --domain=' + distro + '.com --app-archive-path=$APP_ARCHIVE_PATH --device-host=' + name + '.' + distro + '.com --app=' + name + ' --arch=' + arch,
             ],
           }
           for distro in distros
       ] + ( if test_ui then [
       {
            name: "selenium",
            image: "selenium/standalone-" + browser + ":" + selenium,
            detach: true,
            environment: {
                SE_NODE_SESSION_TIMEOUT: "999999",
                START_XVFB: "true"
            },
               volumes: [{
                name: "shm",
                path: "/dev/shm"
            }],
            commands: [
                                     'cat /etc/hosts',
                                     'DOMAIN="' + distro_default + '.com"',
                                     'APP_DOMAIN="' + name + '.' + distro_default + '.com"',
                                     'getent hosts $APP_DOMAIN | sed "s/$APP_DOMAIN/auth.$DOMAIN/g" | sudo tee -a /etc/hosts',
                                     'cat /etc/hosts',
                                     '/opt/bin/entry_point.sh',
                                   ],
         },
    {
        name: "selenium-video",
        image: "selenium/video:ffmpeg-6.1.1-20240517',
        detach: true,
        environment: {
            DISPLAY_CONTAINER_NAME: "selenium",
            FILE_NAME: "video.mkv"
        },
        volumes: [
            {
                name: "shm",
                path: "/dev/shm"
            },
           {
                name: "videos",
                path: "/videos"
            }
        ]
    },        {
            name: "test-ui",
            image: "python:" + python,
            commands: [
              "cd test",
              "./deps.sh",
              "py.test -x -s ui.py --distro=buster --ui-mode=desktop --domain=buster.com --device-host=" + name + ".buster.com --app=" + name + " --browser=" + browser,
            ],
            volumes: [{
                name: "shm",
                path: "/dev/shm"
            }]
        }] else [] ) + [
{
        name: "test-upgrade",
        image: "python:" + python,
        commands: [
          "APP_ARCHIVE_PATH=$(realpath $(cat package.name))",
          "cd test",
          "./deps.sh",
          "py.test -x -s upgrade.py --distro=buster --ui-mode=desktop --domain=buster.com --app-archive-path=$APP_ARCHIVE_PATH --device-host=" + name + ".buster.com --app=" + name + " --browser=" + browser,
        ],
        privileged: true,
        volumes: [{
            name: "videos",
            path: "/videos"
        }]
    },
        {
            name: "upload",
        image: "debian:buster-slim",
        environment: {
            AWS_ACCESS_KEY_ID: {
                from_secret: "AWS_ACCESS_KEY_ID"
            },
            AWS_SECRET_ACCESS_KEY: {
                from_secret: "AWS_SECRET_ACCESS_KEY"
            },
            SYNCLOUD_TOKEN: {
                     from_secret: "SYNCLOUD_TOKEN"
                 }
        },
        commands: [
            "PACKAGE=$(cat package.name)",
            "apt update && apt install -y wget",
            "wget " + deployer + "-" + arch + " -O release --progress=dot:giga",
            "chmod +x release",
            "./release publish -f $PACKAGE -b $DRONE_BRANCH"
        ],
        when: {
            branch: ["stable", "master"]
        }
    },
    {
            name: "promote",
            image: "debian:buster-slim",
            environment: {
                AWS_ACCESS_KEY_ID: {
                    from_secret: "AWS_ACCESS_KEY_ID"
                },
                AWS_SECRET_ACCESS_KEY: {
                    from_secret: "AWS_SECRET_ACCESS_KEY"
                },
                 SYNCLOUD_TOKEN: {
                     from_secret: "SYNCLOUD_TOKEN"
                 }
            },
            commands: [
              "apt update && apt install -y wget",
              "wget " + deployer + "-" + arch + " -O release --progress=dot:giga",
              "chmod +x release",
              "./release promote -n " + name + " -a $(dpkg --print-architecture)"
            ],
            when: {
                branch: ["stable"],
                event: ["push"]
            }
      },
        {
            name: "artifact",
            image: "appleboy/drone-scp:1.6.4",
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
     trigger: {
       event: [
         "push",
         "pull_request"
       ]
     },
    services: [
    {
            name: "docker",
            image: "docker:" + dind,
            privileged: true,
            volumes: [
                {
                    name: "dockersock",
                    path: "/var/run"
                }
            ]
        }
  
    ] + [
    {
      name: name + '.' + distro + '.com',
      image: 'syncloud/platform-' + distro + '-' + arch + ':' + platform,
      privileged: true,
      volumes: [
        {
          name: 'dbus',
          path: '/var/run/dbus',
        },
        {
          name: 'dev',
          path: '/dev',
        },
      ],
    }
    for distro in distros
    ],
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
            name: "dockersock",
            temp: {}
        },
        {
            name: "videos",
            temp: {}
        },
    ]
}];


build("amd64", true, "20.10.21-dind") +
build("arm", false, "19.03.8-dind") +
build("arm64", false, "20.10.21-dind")
