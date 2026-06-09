Требования:
- Наличие docker
- Поместить файлы проекта в emptydir
- Реквизиты базы данных к проекту (если таковая есть), должны быть написаны с использованием переменных окружения 
Запустить в папке с проектом команду для Linux:

    docker build -t devtestops-master . && docker run -it --rm      -v /var/run/docker.sock:/var/run/docker.sock      -v ~/emptydir:/project      devtestops-master

для windows:

    docker build -t devtestops-master . ; if ($?) { docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock -v ${PWD/emptydir}:/project devtestops-master }
