# Instalado os serviços

Para facilitar a construção do ambiente completo, disponibilizados neste repositório um script para fazer a configuração dos serviços.


Será necessário um ambiente Linux (testado com Ubuntu 20.04), com os seguintes programas instalados:

- git - baixar os repositórios
- docker - executar os containers
- docker-compose - gerenciar os containers
- perl - trocar de textos no arquivo .env
- sudo - trocar permissões de usuários
- curl - para testar os serviços
- ngrok - opcional, para exportar um endpoint https para o twitter.

Execute os seguintes comandos:

    git clone https://github.com/AppCivico/politize-chatbot.git politize_project
    cd politize_project/scripts;

Crie uma pasta para manter os projetos, por exemplo:

    mkdir /home/seu-usuario/politize_chatbot

Depois, execute o script abaixo, que irá pedir para você informar este diretório base para o projeto.

O script clone-projects.sh irá clonar os 3 repositórios e fazer o build das imagens, vai criar um arquivo de $BASE_DIR/.env parcialmente preenchido para o docker-compose.

Para executar o script, não é necessário usuário root, porem, o usuário precisa ter permissão para executar o comando `docker` e também ter permissão para trocar o chown de algumas pastas.

O script também irá pedir para informar um nome para o banco de dados. Para este manual, vou usar o valor "prefix_for_db"

    ./clone-projects.sh

Vá até a pasta escolhida, e execute o comando:

    cd /home/seu-usuario/politize_chatbot
    ls -lhas

Você ver os arquivos:

    src                         - código fonte das aplicações (necessário manter, mesmo após o build)
    data                        - diretório para guardar os dados persistentes (bancos de dados e logs)
    docker-compose.yml          - Arquivo como subir os containers
    .env                        - variáveis de ambiente
    db-connect--analytics_db.sh - arquivo para conectar no banco do analytics
    db-connect--quiz_db.sh      - arquivo para conectar no banco do quiz

Inicialmente, para fazer a inicialização do banco sem um race-condition entre o directus e o quiz_api, execute o comando:

    docker-compose up quiz_api

Isso deve subir 3 containers, `quiz_api`, `redis` e `quiz_db` e fazer o start-up do banco de dados. Se tudo ocorrer corretamente, você deverá ver na tela o resultado:

    ```Redirecting STDERR/STDOUT to /data/log//quiz-api.YYYY-MM-DD.log```

Abra um novo terminal, e continue com os passos:

Após subir estes containers, você poderá executar o seguinte comando para entrar no banco do quiz:

    ./db-connect--quiz_db.sh

Execute o comando a seguinte query receber o valor que será necessário atualizar no arquivo .env: POLITIZE_API_TOKEN

    select value from politize_config where name='ANON_QUIZ_SECRET';

Copie esta chave e atualize no arquivo .env o onde estava o valor "get-from-politize_config-on-database"

Aproveite para atualizar também as variáveis que recebeu do processo do twitter, e também as variáveis do SMTP para que o directus consiga enviar os emails de nova conta e esqueci minha senha.

Você pode modificar as outras variáveis, porém, você deverá atualizar os próximos comandos para refletir a atualização.

Após atualizar o arquivo .env, volte para o terminal anterior que está rodando o `docker-compose up quiz_api` e aperte Ctrl+C para encerrar o processo do *docker-compose* com apenas a api, e rode novamente

    docker-compose up

Isso irá subir todos os containers do projeto, com as seguintes configurações de nome/portas:

    IMAGE                            PORTS                       NAMES
    XXXXXXX_webhook_api              172.17.0.1:8021->8080/tcp   webhook_api
    directus/directus:v9.0.0-rc.69   172.17.0.1:8020->8055/tcp   directus
    XXXXXXX_analytics_api            2049/tcp                    analytics_api
    postgres:13.3                    5432/tcp                    analytics_db
    azminas/quiz_api                 8080/tcp                    quiz_api
    bitnami/redis:6.2                6379/tcp                    redis
    postgres:13.3                    5432/tcp                    quiz_db


* Você poderá acessar o directus usando o endereço http://172.17.0.1:8020 e usar o usuário e senha `admin@example.com`
* Você poderá acessar a API de webhook usando o endereço http://172.17.0.1:8021/

> se você tiver problemas e precisar reiniciar, rode o comando `docker rm -f webhook_api directus analytics_api analytics_db quiz_api quiz_db redis` para limpar os containers


## Configurando o quiz

⚠️ Caso você esteja executando os comandos num VPS, você pode conectar utilizando tunnels do ssh:

    ssh -4 -NL 127.0.0.1:8020:172.17.0.1:8020 -NL 127.0.0.1:8021:172.17.0.1:8021 user@seu-vps

> E então utilizar o 127.0.0.1 como IP. também será necessário atualizar a url em DIRECTUS_PUBLIC_URL no arquivo .env e reiniciar o container do directus.

Para o ambiente de produção você irá precisar configurar algum serviço (eg: nginx) para fazer o proxy reverso com SSL. Para ativar o webhook do twitter, vamos utilizar ngrok como exemplo na próxima sessão.

Por enquanto, vamos configurar um fluxo de "bem vindo", que leva para o primeiro questionário utilizando diretamente o acesso ao directus.

Acesse http://172.17.0.1:8020/admin/ e faça o login, depois acesse a página http://172.17.0.1:8020/admin/collections/twitter_bot_config e coloque no campo "Configuração":

    {
        "nodes": [
            {
                "code": "node_tos",
                "type": "text_message",
                "input_type": "quick_reply",
                "messages": [
                    "Olá! Você concorda com os termos?"
                ],
                "quick_replies": [
                    {
                        "label": "👍 Sim",
                        "metadata": "node_tos_accepted"
                    },
                    {
                        "label": "👎 Não",
                        "metadata": "node_tos_refused"
                    }
                ],
                "children": [
                    "node_tos_accepted",
                    "node_tos_refused"
                ]
            },
            {
                "code": "node_welcome_back",
                "type": "text_message",
                "input_type": "quick_reply",
                "messages": [
                    "Bem-vinda de volta! Aperte no botão abaixo para começar novamente"
                ],
                "quick_replies": [
                    {
                        "label": "🔃 Começar novamente",
                        "metadata": "node_tos_accepted"
                    }
                ],
                "children": [
                    "node_tos_accepted"
                ]
            },
            {
                "code": "node_tos_refused",
                "type": "text_message",
                "input_type": "quick_reply",
                "messages": [
                    "Infelizmente não podemos continuar a nossa conversa por aqui."
                ],
                "quick_replies": [
                    {
                        "label": "🔙 Voltar",
                        "metadata": "node_tos"
                    }
                ],
                "children": [
                    "node_tos"
                ]
            },
            {
                "code": "node_tos_accepted",
                "type": "questionnaire",
                "questionnaire_id": "2",
                "is_conversation_end": true,
                "on_conversation_end": "restart",
                "parent": "node_1",
                "children": null
            }
        ],
        "tag_code_config": {
            "default": 0,
            "scenarios": [
                {
                    "tag_code_value": 1,
                    "check_code": "P3a_para_mim"
                },
                {
                    "tag_code_value": 2,
                    "check_code": "P3a_para_outra"
                },
                {
                    "tag_code_value": 3,
                    "check_code": "P2b"
                }
            ]
        },
        "timeout_seconds": 86400,
        "timeout_message": "Vamos nos falar mais tarde!",
        "error_msg": "Não entendi! Utilize os botões abaixo"
    }


Após salvar, é necessário enviar o comando para que o serviço de webhook recarregue as configurações, para isso, vá para um novo terminal e execute:

    curl -X POST 172.17.0.1:8021/config

Se o setup da chave anterior (POLITIZE_API_TOKEN) estiver correta, você deverá receber o retorno `{"message":"OK"}`, isso significa que a configuração foi recarregada com sucesso. Caso a chave esteja errada ou algum problema na configuração do docker-compose, confira a saida do log do container azmina_chatbot_webhook.

Para mais detalhes da configuração do quiz, veja o arquivo [Configurando o Quiz](using-quiz-config.md)


## Configurando webhook do twitter (proxy reverso via ngrok)

Para que o twitter consiga validar o webhook e enviar as dms, ele precisa de um endpoint respondendo em https.

Para fins deste manual, vamos considerar que você está sem domínio e vai utilizar o ngrok para ter um endpoint web temporário.

Primeiro, é necessário criar uma conta no site https://ngrok.com/ e depois instalar o programa ngrok.

    $ baixar o ngrok.zip
    $ unzip ngrok.zip
    $ ./ngrok authtoken SUA_CHAVE_DO_NGROK_VAI_AQUI

Depois, suba um tunnel com o comando:

    $ ./ngrok http 172.17.0.1:8021

Isso irá imprimir na tela algo como:

    Session Status                online
    Account                       suacota-aqui (Plan: Free)
    Version                       2.3.40
    Region                        United States (us)
    Web Interface                 http://127.0.0.1:4040
    Forwarding                    http://3b2b14fbb184.ngrok.io -> http://172.17.0.1:8021
    Forwarding                    https://3b2b14fbb184.ngrok.io -> http://172.17.0.1:8021


Você poderá usar o endereço `https://3b2b14fbb184.ngrok.io` para configurar o webhook do twitter.

Caso deseje acessar o directus, rode uma nova instancia do tunnel com a porta 172.17.0.1:8020, lembrando de atualizar a variável DIRECTUS_PUBLIC_URL e reiniciar o container do directus


