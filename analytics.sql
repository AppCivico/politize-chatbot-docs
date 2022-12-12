-- Número de usuárias únicas
SELECT
  count(distinct c.handle_hashed) as "Número de conversas"
FROM analytics
join conversa c on c.id = analytics.conversa_id
join tag_code on tag_code.id = analytics.tag_code
where 1=1
--[[AND {{first_msg}}]]
--[[AND {{tag_code}}]]


-- Número de usuárias únicas que iniciaram conversas
SELECT
  count(distinct c.handle_hashed) as "Número de conversas"
FROM analytics
join conversa c on c.id = analytics.conversa_id
join tag_code on tag_code.id = analytics.tag_code
where 1=1
and analytics.state != 'DURING_DECISION_TREE'
--[[AND {{first_msg}}]]
--[[AND {{tag_code}}]]

-- Número de usuários únicos com conversas finalizadas
SELECT
  count(distinct c.handle_hashed) as "Número de conversas"
FROM analytics
join conversa c on c.id = analytics.conversa_id
join tag_code on tag_code.id = analytics.tag_code
where 1=1
and analytics.state IN( 'QUESTIONNAIRE_FINISHED', 'QUESTIONNAIRE_GAVE_UP')
--[[AND {{first_msg}}]]
--[[AND {{tag_code}}]]

-- Número de usuários únicos com conversas interrompidas

SELECT
  count(distinct c.handle_hashed) as "Número de conversas"
FROM analytics
join conversa c on c.id = analytics.conversa_id
join tag_code on tag_code.id = analytics.tag_code
where 1=1
and analytics.state IN( 'QUESTIONNAIRE_TIMEOUT')
--[[AND {{first_msg}}]]
--[[AND {{tag_code}}]]

-- Tempo médio da conversa por tipo de finalização

SELECT
  case when state = 'QUESTIONNAIRE_FINISHED' then 'Final do fluxo' when state='QUESTIONNAIRE_GAVE_UP' then 'Botão "Sair" ou "Reiniciar"' when state='QUESTIONNAIRE_TIMEOUT' then 'Timeout' else state::text end as "Tipo",
  percentile_cont(0.5) WITHIN GROUP (ORDER BY  (extract('epoch' from created_at - first_msg_tz) / 60)::int  ) as "Mediana da resposta (em minutos)",
  mode() WITHIN GROUP (ORDER BY (extract('epoch' from created_at - first_msg_tz) / 60)::int  ) as "Tempo mais comum (em minutos)"

FROM analytics
join tag_code on tag_code.id = analytics.tag_code

where 1=1
and analytics.state in( 'QUESTIONNAIRE_FINISHED', 'QUESTIONNAIRE_GAVE_UP', 'QUESTIONNAIRE_TIMEOUT')
--[[AND {{first_msg}}]]
--[[AND {{tag_code}}]]
group by 1
order by 1


-- Número de conversas
SELECT
  count(distinct analytics.conversa_id) as "Número de conversas"
FROM analytics
join tag_code on tag_code.id = analytics.tag_code
where 1=1
--[[AND {{first_msg}}]]
--[[AND {{tag_code}}]]

-- Número de conversas iniciadas
SELECT
  count(distinct analytics.conversa_id) as "Número de conversas"
FROM analytics
join tag_code on tag_code.id = analytics.tag_code
where 1=1
and analytics.state != 'DURING_DECISION_TREE'
--[[AND {{first_msg}}]]
--[[AND {{tag_code}}]]


-- Número de conversas finalizadas
SELECT
  count(distinct analytics.conversa_id) as "Número de conversas"
FROM analytics
join tag_code on tag_code.id = analytics.tag_code
where 1=1
and analytics.state IN ( 'QUESTIONNAIRE_FINISHED', 'QUESTIONNAIRE_GAVE_UP')
--[[AND {{first_msg}}]]
--[[AND {{tag_code}}]]


-- Número de conversas interrompidas
SELECT
  count(distinct analytics.conversa_id) as "Número de conversas"
FROM analytics
join tag_code on tag_code.id = analytics.tag_code
where 1=1
and analytics.state IN ( 'QUESTIONNAIRE_TIMEOUT')
--[[AND {{first_msg}}]]
--[[AND {{tag_code}}]]


-- Locais de saída
SELECT
    sc.code as "Local de saida",
    count(distinct conversa_id) as "Quantidade de conversas",

    percentile_cont(0.5) WITHIN GROUP (ORDER BY  (extract('epoch' from analytics.created_at - analytics.first_msg_tz) / 60)::int  ) as "Mediana da resposta (em minutos)",
    mode() WITHIN GROUP (ORDER BY (extract('epoch' from analytics.created_at - analytics.first_msg_tz) / 60)::int  ) as "Tempo mais comum (em minutos)",
    (extract('epoch' from min( analytics.created_at - analytics.first_msg_tz)) / 60)::int as "Tempo mínimo (minutos)",
    (extract('epoch' from max( analytics.created_at - analytics.first_msg_tz)) / 60)::int as "Tempo máximo (minutos)"
FROM analytics
join step_code sc on sc.id = analytics.step_code_id
join tag_code on tag_code.id = analytics.tag_code
where 1=1
and analytics.state in( 'QUESTIONNAIRE_FINISHED')
[[AND {{first_msg}}]]
[[AND {{tag_code}}]]

group by 1 order by 2 desc;

-- Locais de saída com origem
with by_code as (  SELECT
        step_code_id, analytics.previous_step_code_id,
        sc.code,
        count(1) as count
    FROM analytics
    join step_code sc on sc.id = analytics.step_code_id
    join tag_code on tag_code.id = analytics.tag_code
    where 1=1
    and analytics.state in( 'QUESTIONNAIRE_FINISHED')
    [[AND {{first_msg}}]]
    [[AND {{tag_code}}]]
    group by 1, 2,3
), by_code_total as (
    select code, sum(count) as total
    from by_code
    group by 1
)
select a.code || ' <- ' || sc.code As "Código <- Origem", a.count as "Finalizações", ((a.count / b.total) * 100 )::int ||'%' as "% em relação ao código"
from by_code a
join by_code_total b on b.code=a.code
join step_code sc on sc.id = a.previous_step_code_id
order by b.total desc, a.code;

-- Locais de timeout
SELECT
        sc.code as "Código",
        count(1) as "Quantidade de timeout",
        percentile_cont(0.5) WITHIN GROUP (ORDER BY  (extract('epoch' from analytics.created_at - analytics.first_msg_tz) / 60)::int  ) as "Mediana até desistir (em minutos)",
        mode() WITHIN GROUP (ORDER BY (extract('epoch' from analytics.created_at - analytics.first_msg_tz) / 60)::int  ) as "Tempo mais comum até desistir (em minutos)",
        (extract('epoch' from min( analytics.created_at - analytics.first_msg_tz)) / 60)::int as "Tempo mínimo de até desistir (minutos)",
        (extract('epoch' from max( analytics.created_at - analytics.first_msg_tz)) / 60)::int as "Tempo máximo de até desistir (minutos)"

FROM analytics
join step_code sc on sc.id = analytics.step_code_id
join tag_code on tag_code.id = analytics.tag_code
where 1=1
and analytics.state in( 'QUESTIONNAIRE_TIMEOUT')
    [[AND {{first_msg}}]]
    [[AND {{tag_code}}]]
group by 1
order by 2 desc

