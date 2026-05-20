Иметь docker
Поместить файлы проекта в emptydir
Запустить в папке с проектом команду для Linux:

    docker build -t devtestops-master . && docker run -it --rm      -v /var/run/docker.sock:/var/run/docker.sock      -v ~/emptydir:/project      devtestops-master

для windows:

    docker build -t devtestops-master . ; if ($?) { docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock -v ${PWD/emptydir}:/project devtestops-master }
