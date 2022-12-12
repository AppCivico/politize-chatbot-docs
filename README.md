# Chatbot Politize

Contém documentação para configuração do chatbot Politize em um perfil do Twitter.

# Procedimentos

- Requisitar acesso à API e criar um aplicativo no Twitter - Requer um Perfil com e-mail validado no Twitter
- Configuração do ambiente do webhook, analytics e arvore de decisão
- Opcional: configuração do metabase para acompanhar a utilização.

Para fazer a configuração dos sistemas, é necessário familiaridade com Docker e docker-compose em ambiente Linux.

Para hospedar os serviços, é necessário um host com pelo menos 2GB de RAM, 2 vCPU e 25GB de disco (recomendado SSD).
Para a API de webhook, será necessário um endpoint HTTPS com o certificado funcionando.


# Manuais

* [Requisitar acesso à API e criar um aplicativo no Twitter](twitter-app.md)
* [Configuração dos serviços](installing-services.md)

# Arquitetura

* **Twitter**: Interface de DM dos twitter
* **Webhook**: API que gerencia o estado da conversa, tomando decisões de quando deve ser iniciado um novo questionário, reiniciar o fluxo, encerrar conversas por tempo (timeout)
* **Analytics**: API Proxy para o as tabelas de analytics, atualmente salvando em banco PostgreSQL


## Webhook

Código fonte: https://github.com/AppCivico/politize-chatbot


Contém um webserver com os seguintes endpoints:

* `POST /config` - Recarrega as configurações da arvore de decisão
* `GET /health-check` - Responde 200 quando está com o serviço online
* `GET /twitter-webhook` - Responde com o desafio para fazer a autorização com o twitter
* `POST /twitter-webhook` - Recebe o texto da DM+opções do quick-reply quando existir. Dispara o processamento do texto para gerar mais DMs.

E um script conversation_timeout.js que deve ser executado a cada hora para expirar as conversas que não responderam a tempo.

Uma conversa pode ter vários estados que são controlado por algoritmos diferentes. A primeira delas é o estado *DURING_DECISION_TREE*, que é controlada por uma simples configuração em JSON, e as respostas não são armazenadas, e a outra é *DURING_QUESTIONNAIRE*, que acontece depois que a conversa iniciou um questionário, e cada resposta é armazenada no banco de dados do QuizAPI, e o fluxo pode se basear nas respostas anteriores para mudar de direção.

Ao iniciar o webserver de webhook, uma consulta é feita na QuizAPI para baixar a configuração do bot, para a parte que não é um questionário.

Depois da mensagem de boas vindas, que é configurada na interface do twitter, qualquer mensagem enviada pelo usuário é recebida e se não existir na memoria uma conversa para aquela pessoa, o fluxo é iniciado com o primeiro nó da configuração.


### Tabelas

Ao fazer deploy deste projeto, o banco será populado com as tabelas do directus já preparadas.

O usuário e senha do directus é `admin@example.com`

#### twitter_bot_config

Guarda a configuração em JSON do fluxo de questionários para a parte do *DURING_DECISION_TREE*

#### anonymous_quiz_session

Guarda todas as informações necessárias para execução do quiz (memoria e respostas)



## Analytics

Código fonte: https://github.com/AppCivico/politize-analytics

Contém um webserver com os seguintes endpoints:

* `GET /health-check` - Responde 200 quando está com o serviço online
* `POST /conversa` - Grava um novo evento de conversa, e retorna um ID para que os eventos sejam agrupados
* `POST /analytics` - Grava os eventos de uma conversa e retorna um ID para este evento
* `POST /timeout` - Atualiza o evento para o state QUESTIONNAIRE_TIMEOUT

### Tabelas

#### step_code

Referencia com o nome para cada código de resposta.

Exemplo:
    `ID=1, Code=node_tos, questionnaire_id=Null`


#### conversa

Guarda o horário e com qual @ a conversa aconteceu, para que seja possível contar quantas conversas e com quantas pessoas diferentes elas aconteceram.

Exemplo:
    `ID=1, handle_hashed=(hash do valor da conta do twitter), started_at=Y-M-D H:M:S`

#### analytics

Guarda os eventos de uma conversa.

* Coluna `conversa_id` é sobre qual a conversa.
* Coluna `step_code_id` é sobre qual nó o evento se refere.
* Coluna `previous_step_code_id` é qual o nó anterior da conversa (origem)
* Coluna `state` é um ENUM com os seguintes valores:

    * `DURING_DECISION_TREE` - step_code_id faz parte do json de configuração
    * `DURING_QUESTIONNAIRE` - step_code_id faz parte do questionário
    * `QUESTIONNAIRE_FINISHED` - questionário chegou ao final (no "sucesso" do fluxo, essa é última mensagem de uma conversa), só deve ocorrer uma vez por conversa_id
    * `QUESTIONNAIRE_TIMEOUT` - Quando o questionário não foi respondido a tempo, o ultimo nó que era *DURING_QUESTIONNAIRE* deve virar *QUESTIONNAIRE_TIMEOUT* para marcar os locais que as pessoas pararam de conversar com o bot.
    * `QUESTIONNAIRE_GAVE_UP` - Marca o step_code_id que pessoa desistiu da conversa (comandos "reiniciar" ou botão "Sair")

* Coluna `tag_code` - Marca qual o categoria do evento atual
* Coluna `created_at` - Quando foi enviado essa mensagem
* Coluna `first_msg_tz` - Contém o horário da primeira mensagem, para facilitar os relatórios.
* Coluna `timeout_at` - Contém o horário da que o timeout foi executado

Você pode encontrar algumas queries prontas [neste arquivo](analytics.sql)
