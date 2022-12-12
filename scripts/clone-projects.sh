#!/bin/bash
set -e

# o usuario precisa ter acesso ao docker
docker -v

basepath=
while true ; do
    read -r -p "Digite o diretório para guardar os dados e código fonte dos serviços: " basepath
    if [ -d "$basepath" ] ; then
        break
    fi
    echo "$basepath não é um diretório válido..."
done

dbname=
while true ; do
    read -r -p "Digite um nome para o banco de dados: " dbname
    valid='^[a-z][0-9a-z_]+$'
    if [[ $dbname =~ $valid ]] ; then
        break
    fi
    echo "$dbname não é um nome válido. utilize apenas a-z 0-9 e underline"
done

MY_PATH=$(pwd)

set -x

echo "preparando repositórios em $basepath..."

cp $MY_PATH/env.base $basepath/.env
cp $MY_PATH/docker-compose.yml $basepath/

export dbpass=$(perl -MDigest::MD5 -e 'print Digest::MD5::md5_hex(rand().rand().rand().rand())')
echo "PGPASSWORD=$dbpass psql -h \$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' quiz_db) -U pguser ${dbname}_quiz" > $basepath/db-connect--quiz_db.sh
echo "PGPASSWORD=$dbpass psql -h \$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' analytics_db) -U pguser ${dbname}_analytics" > $basepath/db-connect--analytics_db.sh

chmod +x $basepath/db-connect--quiz_db.sh
chmod +x $basepath/db-connect--analytics_db.sh

perl -pi -w -e "s|_BASEDIR_|$basepath|g;" $basepath/.env
perl -pi -w -e "s|_DBNAME_|$dbname|g;" $basepath/.env
perl -pi -w -e "s|_DBPASS_|$dbpass|g;" $basepath/.env
perl -pi -w -MDigest::MD5 -e 's|random-value-here|Digest::MD5::md5_hex(rand().rand().rand().rand())|ge;' $basepath/.env


cd $basepath

mkdir $basepath/src

git clone https://github.com/institutoazmina/politize_webhook_twitter.git $basepath/src/politize_webhook_twitter
git clone https://github.com/institutoazmina/politize_arvore_decisao.git $basepath/src/politize_arvore_decisao
git clone https://github.com/institutoazmina/politize_analytics.git $basepath/src/politize_analytics

echo "criando diretorios para os dados persistentes..."
mkdir -p $basepath/data/webhook_log/
mkdir -p $basepath/data/quiz_api/log/

# as pastas de dados e código precisam ser escritas pelo user 1000:1000
chown 1000:1000 $basepath/data/ -R
chown 1000:1000 $basepath/src/politize_arvore_decisao -R

echo "fazendo build das imagens (leva um bom tempo!)..."
cd $basepath/src/politize_arvore_decisao/api
./build-container.sh

cd $basepath
docker-compose build

printf "\n\nBuild completado. Configure o arquivo $basepath/.env com as chaves do twitter e outros parametros.\ncd $basepath\n"
