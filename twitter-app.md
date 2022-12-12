# Configuração da conta do Twitter

Será necessário um ambiente Linux (testado com Ubuntu 20.04), com os seguintes programas instalados:

- gem - gerenciador de pacotes do Ruby. Necessário para instalar o twurl

## 1. Requisitar acesso à API

Link para referência do Twitter:: https://developer.twitter.com/en/docs/developer-portal/overview

O primeiro passo para criar um chatbot no Twitter é receber permissão para a utilização da API. Este processo requer uma conta com e-mail validado no Twitter.

Para requisitar acesso à API:

1. Acesse o link: https://developer.twitter.com/en/apply-for-access
2. Aperte no botão “Apply for a developer account”:
2. Ao apertar neste botão, será feito o encaminhamento para outra página, onde será necessário responder perguntas sobre o caso de uso;
2. Um representante do Twitter entrará em contato após o preenchimento dos dados, para dar encaminhamento ao processo de aprovação da conta de desenvolvedor.

## 2. Criar um aplicativo

Link para referência do Twitter: https://developer.twitter.com/en/docs/apps/overview

Após adquirir acesso ao painel de desenvolvedor do Twitter, é necessário criar um aplicativo para o chatbot.

Para criar um aplicativo:

1. Acessar menu “Projects & Apps” -> "Overview", e criar um App na seção “Standalone Apps” em clique em "+ Create App";
1. Digite um nome para o app
1. Guarde todos os tokens! e clique em "App Settings"
4. Assinalar a opção “Read + Write + Direct Messages” na página de permissões do seu App e clicar em "Save"

* "API Key" será usada em TWITTER_CONSUMER_SECRET
* "API Secret Key" será usada em TWITTER_CONSUMER_KEY
* "Bearer Token" não será usado pelo webhook

Agora navegue para "Keys and Tokens" e clique em "Generate". Será gerado duas chaves de consumers, "Access Token" para a variável de ambiente TWITTER_ACCESS_TOKEN e "Access Token Secret" para a variável TWITTER_ACCESS_TOKEN_SECRET


## 3. Configuração da API de webhooks

Link para referência do Twitter:
- https://developer.twitter.com/en/docs/twitter-api/premium/account-activity-api/overview
- https://developer.twitter.com/en/docs/twitter-api/premium/account-activity-api/guides/managing-webhooks-and-subscriptions
- https://developer.twitter.com/en/docs/twitter-api/premium/account-activity-api/api-reference/aaa-premium#post-account-activity-all-env-name-subscriptions

Após a criação e configuração do aplicativo, é necessário adquirir, e configurar, o acesso à API de webhooks.

Para configurar o webhook:

1. Acesse a página de ambientes de desenvolvimento (https://developer.twitter.com/en/account/environments);
1. Crie um ambiente para a “Account Activity API” utilizando o app criado no passo anterior.
1. Será pedido um nome, este nome irá ser utilizado em requisições que serão descritas posteriormente neste guia. Vamos considerar que você escolheu "NOME_QUE_VOCE_ESCOLHEU"
2. Selecione o App criado no passo anterior, e clique em "Complete setup"

Você irá receber uma mensagem parecida com "You are now ready to access Account Activity API with environment label 'NOME_QUE_VOCE_ESCOLHEU'!"

Agora, com faça a autorização do aplicativo auxiliar [Twurl](https://github.com/twitter/twurl) (ferramenta para facilitar requisições feitas para a API do Twitter), pode ser em qualquer computador, não precisa ser no servidor da aplicação.

    twurl authorize --consumer-secret TWITTER_CONSUMER_SECRET --consumer-key TWITTER_CONSUMER_KEY

O comando acima irá retornar uma URL, que te levará ao Twitter para que seja feita a autenticação da página que irá hospedar o chatbot. Depois de autenticar, você deve pegar o código informado na tela, e colocar no terminal, que irá fazer a autenticação e gerar o arquivo `~/.twurlrc`

O arquivo `~/.twurlrc`, caso a conta seja diferente da conta do desenvolvedor, lembre-se de atualizar as variáveis de ambiente TWITTER_ACCESS_TOKEN e TWITTER_ACCESS_TOKEN_SECRET utilizando a chave `token` e `secret` respectivamente (o `consumer_key` e `consumer_secret` são os mesmos enviados pelo parâmetro, logo não precisa de atualização, pois é o mantem o mesmo valor depois da autenticação)

Você agora deve completar a [Configuração dos serviços](installing-services.md) antes de continuar com o cadastro do webhook.
É necessário que o ambiente do webhook esteja acessível para a internet (e o twitter!)

Agora, como dito no manual de instalação, você precisa de uma URL HTTPS externa para responder seu webhook.

Considerando que você subiu o ambiente usando ngrok.io, a url sera algo como `https://f2d6ce738018.ngrok.io/twitter-webhook` você precisa encodar para urlencoded (pode usar o site https://www.urlencoder.org/ para encodar a sua url para você usar no parâmetro ?url=XXXX) e executar o comando a seguir para registrar o webhook:

    twurl -X POST /1.1/account_activity/all/NOME_QUE_VOCE_ESCOLHEU/webhooks.json?url=https%3A%2F%2Ff2d6ce738018.ngrok.io/twitter-webhook

Para listar os webhooks, você pode rodar o comando com GET:

    twurl /1.1/account_activity/all/NOME_QUE_VOCE_ESCOLHEU/webhooks.json

Depois de registrar a webhook, você precisa ativa-la para começar a receber as mensagens, para isso, rode o seguinte comando:

    twurl -X POST /1.1/account_activity/all/NOME_QUE_VOCE_ESCOLHEU/subscriptions.json

Não será apresentada nenhuma saida no sucesso.

O seu chatbot deve estar funcionando neste momento!

⚠️ A conta deve ter a opção de receber DM de desconhecidos ativada. Para isso, vá para twitter.com, clique em "More", depois "Settings and Privacy", na clique na sessão "Privacy and safety", depois "Direct Messages", e tenha certeza que a opção "Allow message requests from everyone" esteja ativada.

