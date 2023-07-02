[Записки о containerd / Хабр](https://habr.com/ru/articles/568274/)

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
