# ИНСТРУКЦИЯ

## Установка gitea

```console
mkdir gitea
cd gitea

```
```console
vim docker-compose.yml
```

```console
version: "3"

networks:
  gitea:
    external: false

services:
  server:
    image: gitea/gitea:1.17.3
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=db:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=gitea
    restart: always
    networks:
      - gitea 
    volumes:
      - ./gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "222:22"
    depends_on:
      - db

  db:
    image: postgres:14
    restart: always
    environment:
      - POSTGRES_USER=gitea
      - POSTGRES_PASSWORD=gitea
      - POSTGRES_DB=gitea
    networks:
      - gitea
    volumes:
      - ./postgres:/var/lib/postgresql/data
```
```console
docker-compose pull
docker-compose up -d
```
Переходим на http://yourip:3000

1. В визарде меняем URL с localhost на ваш ip и инициализируем gitea
2. Регистрируем новую УЗ
3. Создаем новый репозиторий
4. После создания репо возвращаемся в консоль
```console
git clone http://x.x.x.x:3000/gitea/myapp.git  #Клонируем созданный нами репозиторий
```
```console
cd myapp #Переходим в папку с репо
```
```console
unzip app.zip #Разархивируем приложение
```
Теперь запушим распакованные нами файлы в репозиторий
```console
git config --global user.name "Tolya"
git config --global user.email "tolya@gitea.ru"
git add .
git commit -m "uploadfiles"
git push 
```
## Установка Jenkins

```console
mkdir jenkins-config
mkdir ~/jenkins
```
```console
vim jenkins-config/docker-compose.yml
```
```console
version: '3.3'
services:
  jenkins:
    image: jenkins/jenkins:lts
    privileged: true
    user: root
    ports:
      - 8081:8080
      - 50000:50000
    container_name: jenkins
    volumes:
      - ~/jenkins:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - /usr/local/bin/docker:/usr/local/bin/docker
      - /usr/bin/docker:/usr/bin/docker
      - /etc/docker/daemon.json:/etc/docker/daemon.json
```
```console
vim /etc/docker/daemon.json
```
```console
{
    "insecure-registries" : [ "x.x.x.x:5000" ]
}
```
```console
docker-compose up -d
```
Переходим на http://yourip:8081

```console
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```
Выбираем "Install suggested plugins"

## Работа в веб-интерфейсе 

1. Manage Jenkins > Manage Credentials > Jenkins > Global Credentials > Add credentials

Username — пользователь Gitea

Password — пароль пользователя  Gitea

2. Manage Jenkins > Plugins > Доступные > Docker > install without restart

(docker pipeline, docker-build-step, docker slaves, docker, docker api, docker commons)

3. Dashboard > Создать Item > Name > Pipeline > OK
   1. Идем во вкладку **Pipeline**
   2. В разделе **Definition** выбираем **"Pipeline script from SCM"**
   3. В разделе **SCM** выбираем **"Git"**
   4. В разделе **Repositories** заполняем Repository URL ссылкой на раннее созданный нами реп
   5. В разделе **Credentials** выбираем созданные раннее креды от пользователя gitea
   6. В разделе Branches **Specifier** меняем master на main (в случае если при создания репозитория вы не меняли названия основной ветки) 
   7. Нажимаем **"Сохранить"**

## Написание пайплайна

```console
cd myapp #Переходим в папку с репозиторием
```
```console
vim Jenkinsfile
```
```console
node {
    def app

    stage('Clone repo') {
        checkout scm
    }

    stage('Build image'){
        app = docker.build("myapp/test")
    }

    stage('Push image') {
        docker.withRegistry('http://x.x.x.x:5000') {
            app.push("${env.BUILD_NUMBER}")
            app.push("latest")
        }
    }
}
```
```console
git add Jenkinsfile
git commit -m "Add jenkinsfile"
git push
```
## Между делом поднимем локально реджестри чтобы было куда пушить

```console
docker run -d -p 5000:5000 --restart=always --name registry registry:2
```

## Проверка работоспособности пайплайна

1. Переходим в дашборд дженкинса
2. Выбираем раннее созданный нами итем
3. Нажимаем "Собрать сейчас"
4. Ожидаем
5. В итоге мы должны видеть успешно прокатанные стейджи (Реп успешно склонирован, образ успешно собрался и успешно запушился в локальный реджестри)

*Для дебага: выбираем сборку и смотрим вывод консоли*

