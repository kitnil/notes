# [Записки о containerd / Хабр](https://habr.com/ru/articles/568274/)

> Когда в пятый раз у тебя появляется на работе падаван, которому надо все рассказать по нескольку раз, в какой-то момент приходит в голову светлая мысль все свои речи законспектировать, попутно хоть немного структурировав все это дело. Так что сия заметка о сontainerd для того, чтобы не повторяться в сотый раз. Возможно, кому-то еще это будет интересно, хотя тут все без рокет-сайнс.
> 
> После скачивания архива из релиза containerd мы получаем набор бинарей:
> 
> -   containerd
>     
> -   containerd-shim
>     
> -   containerd-shim-runc-v1
>     
> -   containerd-shim-runc-v2
>     
> -   crictl
>     
> -   ctr
>     
> 
> Демон containerd по умолчанию использует файловую систему overlayfs для сборки конечного образа из "снапшотов". В терминологии containerd так называют "слои" докер/cri образов. Поэтому стоит проследить чтобы модуль overlay был включен в ядре (modprobe overlay) Дефолтный systemd-unit можно найти в [репозитории](https://github.com/containerd/containerd/blob/main/containerd.service).
> 
> [Пример конфига](https://github.com/containerd/containerd/blob/main/docs/man/containerd-config.toml.5.md) containerd, а также [здесь](https://github.com/containerd/containerd/blob/main/docs/cri/config.md) есть более подробное описание всей структуры конфига. В частности, описано как настроить insecure registry
> 
> Пример
> 
>     [plugins]
>       [plugins.cri.containerd]
>         snapshotter = "overlayfs"
>         [plugins.cri.registry.mirrors."local.insecure-registry.io"]
>           endpoint = [" http://registry.com:5000"]
> 
> Kubelet взаимодействует с containerd через сокет, расположение которого указывается через аргумент:
> 
> _\--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock_
> 
> Сontainerd, получив спеки от кубелета, запускает контейнеры через прослойку - containerd-shim, который уже в свою очередь выполняет бинарь рантайма с нужными параметрами. Эталонной реализацией считается [runc](https://github.com/opencontainers/runc/releases).
> 
> В данный момент есть две версии api, которое использует containerd-shim. На данный момент актуальной является v2. (Прошу понять и простить за то, что примеры будут с v1). Подробнее описано [здесь](https://github.com/containerd/containerd/blob/main/runtime/v2/README.md).
> 
> Сontainerd-shim позволяет не привязывать процессы, запущенные в контейнере к демону containerd, что есть весьма хорошо, на случай если вы вдруг решили, например, добавить внезапно "insecure registry" или другой параметр в конфиге и, вследствие этого, понадобилось перезапустить демон containerd. Если посмотреть на список процессов, то можно увидеть что изолированные процессы являются дочерними по отношению к containerd-shim, который в свою очередь выглядит примерно следующим образом:
> 
> _containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/2d538b1bdc00a5f6251c9f47babca6163794a065133bcd2a0a0264a37a533644 -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd_
> 
> **\-namespace** в данному случае - это не тот, немспейс, который в кубе. Это изолированный раздел в рамках самого containerd. Для kubelet'а по умолчанию создается немспейс k8s, но вы можете создать другой, если вдруг нашли оркестратор получше или запускаете что-то руками.
> 
> **\-workdir** определяет рабочую директорию для процесса, как ни странно.
> 
> **\-address** и **\-containerd-binary** указывают на сокет и бинарь containerd (а точнее, containerd-shim стучится в аргумент "containerd publish"), для того, чтобы уведомлять о состоянии контейнера в основной демон. Именно из-за этого, в случае рестарта containerd, шимы оперативно сообщат о своем состоянии и вы сможете наблюдать актуальную картину запущенных контейнеров без запуска всего с нуля для приведения к тому состоянию, которое от него требует kubelet.
> 
> Собственно, запуск контейнеров осуществляется не самим containerd, а через исполняемый файл рантайма, коих в наше время больше, чем кажется. Эталонным в наше время, как уже было отмечено, является runc, который и занимается, собственно, изоляцией или "контейнеризацией". Запускать контейнеры можно и напрямую через него (runc --help), однако при использовании containerd, _runc list_ нам ничего не покажет. Это потому, что директория с информацией о запущенных контейнерах хранится в другом месте, в частности контейнеры бьются на каталоги соответствующие немспейсам containerd, например для куба это:
> 
> _runc --root /run/containerd/runc/k8s.io/ list_
> 
> Можете посмотреть состояние какого-нибудь контейнера, например:
> 
> _root@kube03a:~#_ _runc --root /run/containerd/runc/k8s.io/ state 2d538b1bdc00a5f6251c9f47babca6163794a065133bcd2a0a0264a37a533644_
> 
> Результат
> 
>     {
>       "ociVersion": "1.0.2-dev",
>       "id": "2d538b1bdc00a5f6251c9f47babca6163794a065133bcd2a0a0264a37a533644",
>       "pid": 28627,
>       "status": "running",
>       "bundle": "/run/containerd/io.containerd.runtime.v1.linux/k8s.io/2d538b1bdc00a5f6251c9f47babca6163794a065133bcd2a0a0264a37a533644",
>       "rootfs": "/run/containerd/io.containerd.runtime.v1.linux/k8s.io/2d538b1bdc00a5f6251c9f47babca6163794a065133bcd2a0a0264a37a533644/rootfs",
>       "created": "2021-07-05T02:22:28.018197224Z",
>       "annotations": {
>         "io.kubernetes.cri.container-name": "nginx",
>         "io.kubernetes.cri.container-type": "container",
>         "io.kubernetes.cri.image-name": "docker.io/library/nginx:latest",
>         "io.kubernetes.cri.sandbox-id": "aae43202632ad129b71f6672c3ca089e76a399d6234d89cc08751b85645f31c6",
>         "io.kubernetes.cri.sandbox-name": "nginx-7848d4b86f-xztfp",
>         "io.kubernetes.cri.sandbox-namespace": "default"
>       },
>       "owner": ""
>     }
> 
> Но runc, за счет своей низкоуровневости, не самое лучшее место для просмотра состояния контейнеров. Containerd распологает двумя утилитами для взаимодействия пользователя с ним: crictl и ctr.
> 
> **crictl** является основной утилитой для взаимодействия с containerd. Помимо аналога действий, присущих docker cli (наподобие _create_, _exec_, _images_ и тд), есть и более интересные. К примеру, containerd знает о существовании таких сущностей, как кубовые поды (_runp_, _rmp_, _pods_, _stopp_, _inspectp_). Попробую вкратце упомянуть некоторые интересные вещи. Если вдруг containerd демон запущен, а crictl ругается что не может найти его, укажите сокет напрямую, например:
> 
> _crictl --runtime-endpoint /var/run/containerd/containerd.sock_
> 
> Начнем с info:
> 
> _root@kube03a:~# crictl info 2d538b1bdc00a | jq -r '.status'_
> 
> Результат
> 
>     {
>       "conditions": [
>         {
>           "type": "RuntimeReady",
>           "status": true,
>           "reason": "",
>           "message": ""
>         },
>         {
>           "type": "NetworkReady",
>           "status": true,
>           "reason": "",
>           "message": ""
>         }
>       ]
>     }
> 
> **crictl inspect** и **inspectp** выведет крайне много интересной информации. Описывать все это бессмыслено, да и все вполне очевидно. Например перечисляются маунты:
> 
> _crictl inspect 2d538b1bdc00a | jq -r '.info.runtimeSpec.mounts\[\]'_
> 
> ...где сможем видеть сгенерированный resolv.conf
> 
>     ...
>     {
>       "destination": "/etc/resolv.conf",
>       "type": "bind",
>       "source": "/var/lib/containerd/io.containerd.grpc.v1.cri/sandboxes/aae43202632ad129b71f6672c3ca089e76a399d6234d89cc08751b85645f31c6/resolv.conf",
>       "options": [
>         "rbind",
>         "rprivate",
>         "rw"
>       ]
>     }
>     ...
> 
> Или сетевые устройства в поде:
> 
> _crictl inspectp aae43202632ad | jq -r '.info.cniResult.Interfaces'_
> 
> Результат
> 
>     {
>       "cnio0": {
>         "IPConfigs": null,
>         "Mac": "3e:44:1a:e2:03:f0",
>         "Sandbox": ""
>       },
>       "eth0": {
>         "IPConfigs": [
>           {
>             "IP": "10.150.21.7",
>             "Gateway": "10.150.21.1"
>           }
>         ],
>         "Mac": "5a:fe:ec:a0:c2:59",
>         "Sandbox": "/var/run/netns/cni-6070de8e-4e69-99c0-e619-63535af42ce5"
>       },
>       "lo": {
>         "IPConfigs": [
>           {
>             "IP": "127.0.0.1",
>             "Gateway": ""
>           },
>           {
>             "IP": "::1",
>             "Gateway": ""
>           }
>         ],
>         "Mac": "00:00:00:00:00:00",
>         "Sandbox": "/var/run/netns/cni-6070de8e-4e69-99c0-e619-63535af42ce5"
>       },
>       "veth335fa7aa": {
>         "IPConfigs": null,
>         "Mac": "de:30:14:fa:26:57",
>         "Sandbox": ""
>       }
>     }
> 
> Из этого вывода или с помощью команды:
> 
> _crictl inspectp aae43202632ad | jq -r '.info.runtimeSpec.linux.namespaces'_
> 
> вы сможете обнаружить имя изолированного сетевого немспейса (это уже совсем-совсем другой немспейс)
> 
>     ... 
>       {
>         "type": "network",
>         "path": "/var/run/netns/cni-6070de8e-4e69-99c0-e619-63535af42ce5"
>       }
>     ...
> 
> Вбиваем
> 
> _ip netns exec cni-6070de8e-4e69-99c0-e619-63535af42ce5 ip a show type veth_
> 
> и получаем параметры сети в испектируемом поде.
> 
> Возвращаемся к crictl.
> 
> **crictl stats -a** вернет нам табличку с потребляемыми ресурсами (_cpu_, _disk_, _mem_, _inodes_), а флаг _\-o json_ вернет нам все еще и в json виде, на случай если вы вдруг что-то мониторите.
> 
> К слову, crictl imagefsinfo вернет вам что-то вроде:
> 
>     {
>       "status": {
>         "timestamp": "1626124762748935841",
>         "fsId": {
>           "mountpoint": "/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs"
>         },
>         "usedBytes": {
>           "value": "1969491968"
>         },
>         "inodesUsed": {
>           "value": "77458"
>         }
>       }
>     }
> 
> Еще мы можем, например, посмотреть на процесс внутри контейнера:
> 
> _root@kube03a:~# cat "/proc/$(crictl inspect 2d538b1bdc00a | jq -r '.info.pid')/cmdline"_
> 
> ...вернет:
> 
> _nginx: master process nginx -g daemon off;_
> 
> А в корневой каталог попасть через /proc/$PID/root/
> 
> _root@kube03a:~# cat "/proc/$(crictl inspect 2d538b1bdc00a | jq -r '.info.pid')/root/etc/hostname"_
> 
> _nginx-7848d4b86f-xztfp_
> 
> Мы видим что все, что было в inpect в списке для монтирования, на этом этапе уже на своем месте.
> 
> Можем еще получить, например, id контейнера:
> 
> _сrictl inspect 2d538b1bdc00a | jq -r '.status.id'_
> 
> _2d538b1bdc00a5f6251c9f47babca6163794a065133bcd2a0a0264a37a533644_
> 
> Через этот id мы можем найти каталог с его конфигами:
> 
> _root@kube03a:~# ls /var/run/containerd/io.containerd.runtime.v1.linux/k8s.io/$(crictl inspect 2d538b1bdc00a | jq -r '.status.id')_
> 
> _address config.json init.pid log.json rootfs shim.pid_
> 
> **init.pid** содержит уже известный нам pid процесса в контейнере, а **shim.pid** - pid родительского containerd-shim. В каталоге **rootfs** содержится собранный из снапшотов (слоев) overlayfs запущенного контейнера, но без дополнительных монтирований.
> 
> Если посмотреть на cgroups, то тут есть два варианта, в зависимости от выбранного драйвера cgroups. Если выбран драйвер systemd, то путь в cgroups\_v1 будет примерно следующий:
> 
> _root@kube03a:~# cat /sys/fs/cgroup/pids/system.slice/containerd.service/kubepods-besteffort-pod$(crictl inspectp aae43202632ad | jq -r '.status.metadata.uid' | sed 's/-/\_/g').slice:cri-containerd:$(crictl inspect 2d538b1bdc00a | jq -r '.status.id')/cgroup.procs_
> 
>     28627
>     28664
>     28665
> 
> _по человечески:_
> 
> _cat /sys/fs/cgroup/pids/system.slice/containerd.service/kubepods-besteffort-podc7205bb2\_8c97\_4f79\_b4c9\_915e402cc7d3.slice:cri-containerd:2d538b1bdc00a5f6251c9f47babca6163794a065133bcd2a0a0264a37a533644/cgroup.procs_
> 
> _crictl inspectp aae43202632ad | jq -r '.status.metadata.uid'_ - вернет нам **uid** пода, а _crictl inspect 2d538b1bdc00a | jq -r '.status.id'_ - уже известный нам **id** контейнера. По аналогии можно обратиться к другим cgroups директориям.
> 
> Если же у вас драйвером выбран cgroups:
> 
> _cat /sys/fs/cgroup/pids/kubepods/pod7d5e31f8-8797-457d-aaf2-f55464d338c6/eb2c3ad61742de7ed7a8758cc563a1470b969632f857429787668e1f354e357a/cgroup.procs_
> 
> В реалтайме вы можете посмотреть cgroups через `systemd-cgtop -m`. Тут ведь все любят systemd, так?
> 
> Дошли наконец-таки до ctr
> 
> Для начала можно посмотреть доступные встроенные плагины.
> 
> _ctr plugins ls_ - здесь можно посмотреть доступные снапшоттеры, которые составляют из слоев докер-образа конечный образ. Есть поддержа ZFS и BTRFS.
> 
> Далее смотрим доступные немспейсы containerd:
> 
> _ctr namespaces ls_
> 
> По умолчанию доступен немспейс "k8s.io". В дальнейших командах необходимо его явно указать: _ctr --namespace=k8s.io containers ls_
> 
> Так же можно посмотреть _images_ (образы), _events_ (отлов событий), _content_ (бинарные данные из образов), _snapshots_ (слои из образов), _leases_ (аренда каких-либо ресурсов, [подробней](https://github.com/containerd/containerd/blob/main/docs/garbage-collection.md) ), _tasks_ (запущенные в контейнерах процессы).
> 
> Из необычного, вы можете взаимодействовать напрямую с shim или установить бинари и библиотеки из образа через _crt install_ (это, видимо, для особо прогрессивных).
> 
> Напоследок [ссылка](https://kubernetes.io/docs/tasks/debug-application-cluster/crictl/#create-a-container) на описание запуска контейнера через crictl для дебага.

# [containerd: docs/hosts.md | Fossies](https://fossies.org/linux/containerd/docs/hosts.md)

> ## ![](https://fossies.org/warix/forest1.gif) "[Fossies](https://fossies.org/)" - the Fresh Open Source Software Archive ![](https://fossies.org/warix/forest2.gif)
> 
> ### Member "containerd-1.7.2/docs/hosts.md" (2 Jun 2023, 13086 Bytes) of package [/](https://fossies.org/ "Fossies homepage")[linux](https://fossies.org/linux/ "Listing of all main folders within the Fossies basic folder /linux/")/[misc](https://fossies.org/linux/misc/ "Listing of all packages within the Fossies folder /linux/misc/")/[containerd-1.7.2.tar.gz](https://fossies.org/linux/misc/containerd-1.7.2.tar.gz/ "Contents listing, member browsing, download with different compression formats & more ..."):
> 
> * * *
> 
> As a special service "Fossies" has tried to format the requested source page into HTML format (assuming markdown format). Alternatively you can here [view](https://fossies.org/linux/misc/containerd-1.7.2.tar.gz/containerd-1.7.2/docs/hosts.md?m=t) or [download](https://fossies.org/linux/misc/containerd-1.7.2.tar.gz/containerd-1.7.2/docs/hosts.md?m=b) the uninterpreted source code file. A member file download can also be achieved by clicking within a package contents listing on the according byte size field. See also the last [Fossies "Diffs"](https://fossies.org/diffs/ "Fossies source code differences reports (main page)") side-by-side code changes report for "hosts.md": [![](https://fossies.org/delta_answer_10.png) 1.6.19\_vs\_1.7.0](https://fossies.org/diffs/containerd/1.6.19_vs_1.7.0/docs/hosts.md-diff.html ""hosts.md" file currently unchanged, last changes on Fossies in a previous release report.").
> 
> * * *
> 
> # Registry Configuration - Introduction
> 
> New and additional registry hosts config support has been implemented in containerd v1.5 for the `ctr` client (the containerd tool for admins/developers), containerd image service clients, and CRI clients such as `kubectl` and `crictl`.
> 
> Configuring registries, for these clients, will be done by specifying (optionally) a `hosts.toml` file for each desired registry host in a configuration directory. **Note**: Updates under this directory do not require restarting the containerd daemon.
> 
> ## Registry API Support
> 
> All configured registry hosts are expected to comply with the [OCI Distribution Specification](https://github.com/opencontainers/distribution-spec). Registries which are non-compliant or implement non-standard behavior are not guaranteed to be supported and may break unexpectedly between releases.
> 
> Currently supported OCI Distribution version: **[v1.0.0](https://github.com/opencontainers/distribution-spec/tree/v1.0.0)**
> 
> ## Specifying the Configuration Directory
> 
> ### Using Host Namespace Configs with CTR
> 
> When pulling a container image via `ctr` using the `--hosts-dir` option tells `ctr` to find and use the host configuration files located in the specified path:
> 
>     ctr images pull --hosts-dir "/etc/containerd/certs.d" myregistry.io:5000/image_name:tag
> 
> ### CRI
> 
> _The old CRI config pattern for specifying registry.mirrors and registry.configs has been **DEPRECATED**._ You should now point your registry `config_path` to the path where your `hosts.toml` files are located.
> 
> Modify your `config.toml` (default location: `/etc/containerd/config.toml`) as follows:
> 
>     version = 2
>     
>     [plugins."io.containerd.grpc.v1.cri".registry]
>        config_path = "/etc/containerd/certs.d"
> 
> ## Support for Docker's Certificate File Pattern
> 
> If no hosts.toml configuration exists in the host directory, it will fallback to check certificate files based on [Docker's certificate file pattern](https://docs.docker.com/engine/reference/commandline/dockerd/#insecure-registries) (".crt" files for CA certificates and ".cert"/".key" files for client certificates).
> 
> ## Registry Host Namespace
> 
> A registry host is the location where container images and artifacts are sourced. These registry hosts may be local or remote and are typically accessed via http/https using the [OCI distribution specification](https://github.com/opencontainers/distribution-spec/blob/main/spec.md). A registry mirror is not a registry host but these mirrors can also be used to pull content. Registry hosts are typically referred to by their internet domain names, aka. registry host names. For example, docker.io, quay.io, gcr.io, and ghcr.io.
> 
> A registry host namespace is, for the purpose of containerd registry configuration, a path to the `hosts.toml` file specified by the registry host name, or ip address, and an optional port identifier. When making a pull request for an image the format is typically as follows:
> 
>     pull [registry_host_name|IP address][:port][/v2][/org_path]<image_name>[:tag|@DIGEST]
> 
> The registry host namespace portion is `[registry_host_name|IP address][:port]`. Example tree for docker.io:
> 
>     $ tree /etc/containerd/certs.d
>     /etc/containerd/certs.d
>     └── docker.io
>         └── hosts.toml
> 
> Optionally the `_default` registry host namespace can be used as a fallback, if no other namespace matches.
> 
> The `/v2` portion of the pull request format shown above refers to the version of the distribution api. If not included in the pull request, `/v2` is added by default for all clients compliant to the distribution specification linked above.
> 
> For example when pulling image\_name:tag from a private registry named myregistry.io over port 5000:
> 
>     pull myregistry.io:5000/image_name:tag
> 
> The pull will resolve to `https://myregistry.io:5000/v2/image_name:tag`
> 
> ## Specifying Registry Credentials
> 
> ### CTR
> 
> When performing image operations via `ctr` use the --help option to get a list of options you can set for specifying credentials:
> 
>     ctr i pull --help
>     ...
>     OPTIONS:
>        --skip-verify, -k                 skip SSL certificate validation
>        --plain-http                      allow connections using plain HTTP
>        --user value, -u value            user[:password] Registry user and password
>        --refresh value                   refresh token for authorization server
>        --hosts-dir value                 Custom hosts configuration directory
>        --tlscacert value                 path to TLS root CA
>        --tlscert value                   path to TLS client certificate
>        --tlskey value                    path to TLS client key
>        --http-dump                       dump all HTTP request/responses when interacting with container registry
>        --http-trace                      enable HTTP tracing for registry interactions
>        --snapshotter value               snapshotter name. Empty value stands for the default value. [$CONTAINERD_SNAPSHOTTER]
>        --label value                     labels to attach to the image
>        --platform value                  Pull content from a specific platform
>        --all-platforms                   pull content and metadata from all platforms
>        --all-metadata                    Pull metadata for all platforms
>        --print-chainid                   Print the resulting image's chain ID
>        --max-concurrent-downloads value  Set the max concurrent downloads for each pull (default: 0)
> 
> ## CRI
> 
> Although we have deprecated the old CRI config pattern for specifying registry.mirrors and registry.configs you can still specify your credentials via [CRI config](https://github.com/containerd/containerd/blob/main/docs/cri/registry.md#configure-registry-credentials).
> 
> Additionally, the containerd CRI plugin implements/supports the authentication parameters passed in through CRI pull image service requests. For example, when containerd is the container runtime implementation for `Kubernetes`, the containerd CRI plugin receives authentication credentials from kubelet as retrieved from [Kubernetes Image Pull Secrets](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)
> 
> # Registry Configuration - Examples
> 
> ### Simple (default) Host Config for Docker
> 
> Here is a simple example for a default registry hosts configuration. Set `config_path = "/etc/containerd/certs.d"` in your config.toml for containerd. Make a directory tree at the config path that includes `docker.io` as a directory representing the host namespace to be configured. Then add a `hosts.toml` file in the `docker.io` to configure the host namespace. It should look like this:
> 
>     $ tree /etc/containerd/certs.d
>     /etc/containerd/certs.d
>     └── docker.io
>         └── hosts.toml
>     
>     $ cat /etc/containerd/certs.d/docker.io/hosts.toml
>     server = "https://docker.io"
>     
>     [host."https://registry-1.docker.io"]
>       capabilities = ["pull", "resolve"]
> 
> ### Setup a Local Mirror for Docker
> 
>     server = "https://registry-1.docker.io"    # Exclude this to not use upstream
>     
>     [host."https://public-mirror.example.com"]
>       capabilities = ["pull"]                  # Requires less trust, won't resolve tag to digest from this host
>     [host."https://docker-mirror.internal"]
>       capabilities = ["pull", "resolve"]
>       ca = "docker-mirror.crt"                 # Or absolute path /etc/containerd/certs.d/docker.io/docker-mirror.crt
> 
> ### Setup Default Mirror for All Registries
> 
>     $ tree /etc/containerd/certs.d
>     /etc/containerd/certs.d
>     └── _default
>         └── hosts.toml
>     
>     $ cat /etc/containerd/certs.d/_default/hosts.toml
>     server = "https://registry.example.com"
>     
>     [host."https://registry.example.com"]
>       capabilities = ["pull", "resolve"]
> 
> ### Bypass TLS Verification Example
> 
> To bypass the TLS verification for a private registry at `192.168.31.250:5000`
> 
> Create a path and `hosts.toml` text at the path "/etc/containerd/certs.d/docker.io/hosts.toml" with following or similar contents:
> 
>     server = "https://registry-1.docker.io"
>     
>     [host."http://192.168.31.250:5000"]
>       capabilities = ["pull", "resolve", "push"]
>       skip_verify = true
> 
> # hosts.toml Content Description - Detail
> 
> For each registry host namespace directory in your registry `config_path` you may include a `hosts.toml` configuration file. The following root level toml fields apply to the registry host namespace:
> 
> **Note**: All paths specified in the `hosts.toml` file may be absolute or relative to the `hosts.toml` file.
> 
> ## server field
> 
> `server` specifies the default server for this registry host namespace. When `host`(s) are specified, the hosts are tried first in the order listed.
> 
>     server = "https://docker.io"
> 
> ## capabilities field
> 
> `capabilities` is an optional setting for specifying what operations a host is capable of performing. Include only the values that apply.
> 
>     capabilities =  ["pull", "resolve", "push"]
> 
> capabilities (or Host capabilities) represent the capabilities of the registry host. This also represents the set of operations for which the registry host may be trusted to perform.
> 
> For example, pushing is a capability which should only be performed on an upstream source, not a mirror.
> 
> Resolving (the process of converting a name into a digest) must be considered a trusted operation and only done by a host which is trusted (or more preferably by secure process which can prove the provenance of the mapping).
> 
> A public mirror should never be trusted to do a resolve action.
> 
> Registry Type
> 
> Pull
> 
> Resolve
> 
> Push
> 
> Public Registry
> 
> yes
> 
> yes
> 
> yes
> 
> Private Registry
> 
> yes
> 
> yes
> 
> yes
> 
> Public Mirror
> 
> yes
> 
> no
> 
> no
> 
> Private Mirror
> 
> yes
> 
> yes
> 
> no
> 
> ## ca field
> 
> `ca` (Certificate Authority Certification) can be set to a path or an array of paths each pointing to a ca file for use in authenticating with the registry namespace.
> 
>     ca = "/etc/certs/mirror.pem"
> 
> or
> 
>     ca = ["/etc/certs/test-1-ca.pem", "/etc/certs/special.pem"]
> 
> ## client field
> 
> `client` certificates are configured as follows
> 
> a path:
> 
>     client = "/etc/certs/client.pem"
> 
> an array of paths:
> 
>     client = ["/etc/certs/client-1.pem", "/etc/certs/client-2.pem"]
> 
> an array of pairs of paths:
> 
>     client = [["/etc/certs/client.cert", "/etc/certs/client.key"],["/etc/certs/client.pem", ""]]
> 
> ## skip\_verify field
> 
> `skip_verify` skips verifications of the registry's certificate chain and host name when set to `true`. This should only be used for testing or in combination with other method of verifying connections. (Defaults to `false`)
> 
>     skip_verify = false
> 
> ## header fields (in the toml table format)
> 
> `[header]` contains some number of keys where each key is to one of a string or
> 
> an array of strings as follows:
> 
>     [header]
>       x-custom-1 = "custom header"
> 
> or
> 
>     [header]
>       x-custom-1 = ["custom header part a","part b"]
> 
> or
> 
>     [header]
>       x-custom-1 = "custom header",
>       x-custom-1-2 = "another custom header"
> 
> ## override\_path field
> 
> `override_path` is used to indicate the host's API root endpoint is defined in the URL path rather than by the API specification. This may be used with non-compliant OCI registries which are missing the `/v2` prefix. (Defaults to `false`)
> 
>     override_path = true
> 
> ## host field(s) (in the toml table format)
> 
> `[host]."https://namespace"` and `[host].http://namespace` entries in the `hosts.toml` configuration are registry namespaces used in lieu of the default registry host namespace. These hosts are sometimes called mirrors because they may contain a copy of the container images and artifacts you are attempting to retrieve from the default registry. Each `host`/`mirror` namespace is also configured in much the same way as the default registry namespace. Notably the `server` is not specified in the `host` description because it is specified in the namespace. Here are a few rough examples configuring host mirror namespaces for this registry host namespace:
> 
>     [host."https://mirror.registry"]
>       capabilities = ["pull"]
>       ca = "/etc/certs/mirror.pem"
>       skip_verify = false
>       [host."https://mirror.registry".header]
>         x-custom-2 = ["value1", "value2"]
>     
>     [host."https://mirror-bak.registry/us"]
>       capabilities = ["pull"]
>       skip_verify = true
>     
>     [host."http://mirror.registry"]
>       capabilities = ["pull"]
>     
>     [host."https://test-1.registry"]
>       capabilities = ["pull", "resolve", "push"]
>       ca = ["/etc/certs/test-1-ca.pem", "/etc/certs/special.pem"]
>       client = [["/etc/certs/client.cert", "/etc/certs/client.key"],["/etc/certs/client.pem", ""]]
>     
>     [host."https://test-2.registry"]
>       client = "/etc/certs/client.pem"
>     
>     [host."https://test-3.registry"]
>       client = ["/etc/certs/client-1.pem", "/etc/certs/client-2.pem"]
>     
>     [host."https://non-compliant-mirror.registry/v2/upstream"]
>       capabilities = ["pull"]
>       override_path = true
> 
> **Note**: Recursion is not supported in the specification of host mirror namespaces in the hosts.toml file. Thus the following is not allowed/supported:
> 
>     [host."http://mirror.registry"]
>       capabilities = ["pull"]
>       [host."http://double-mirror.registry"]
>         capabilities = ["pull"]
