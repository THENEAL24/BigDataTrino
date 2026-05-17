## Что использовалось

```text
- Docker - весь стек
- PostgreSQL 16-alpine - 5000 строк mock_data, файлы MOCK_DATA (5)…(9).csv
- ClickHouse 24.8 - 5000 строк mock_data, файлы MOCK_DATA.csv и (1)…(4).csv
- Trino 453 - ETL SQL в ClickHouse (каталоги postgresql + clickhouse)
```

Порты на хосте в `docker-compose.yml` смещены, если заняты обычные: postgres `15432`, clickhouse http `18123`, trino `18080`. Внутри сети compose имена сервисов те же: `postgres`, `clickhouse`, `trino`.

Имена контейнеров: `bigdata-trino-lab4-postgres`, `bigdata-trino-lab4-clickhouse`, `bigdata-trino-lab4-clickhouse-init`, `bigdata-trino-lab4-trino`.


## Что вводить

Десять CSV лежат в `data/` в корне `BigDataTrino` (compose монтирует эту папку в Postgres и ClickHouse).

1. Зайти в каталог лабы

```text
cd BigDataTrino
```

2. Поднять всё

```text
docker compose up -d
```

3. Убедиться что контейнеры есть

```text
docker ps
```

4. Подождать пока отработает init clickhouse (в логах будет строка про 5000 строк)

```text
docker logs bigdata-trino-lab4-clickhouse-init
```

5. Проверить postgres

```text
docker exec -it bigdata-trino-lab4-postgres psql -U postgres -d lab_db -c "SELECT count(*) FROM mock_data;"
```

Должно быть 5000.

6. Проверить сырой clickhouse

```text
docker exec -it bigdata-trino-lab4-clickhouse clickhouse-client -q "SELECT count() FROM default.mock_data"
```

Тоже 5000.

7. Прогнать trino-скрипты по очереди (лучше `-f`, операторы идут последовательно; редирект всего файла в stdin иногда даёт гонки)

```text
docker exec bigdata-trino-lab4-trino trino http://localhost:8080 -f /sql/01_create_dwh.sql
docker exec bigdata-trino-lab4-trino trino http://localhost:8080 -f /sql/02_load_dimensions_and_fact.sql
docker exec bigdata-trino-lab4-trino trino http://localhost:8080 -f /sql/03_load_reports.sql
```

8. Проверить витрины в clickhouse (6 таблиц в `reports`)

```text
docker exec -it bigdata-trino-lab4-clickhouse clickhouse-client -q "SHOW TABLES FROM reports"
```

9. Пример выборки

```text
docker exec -it bigdata-trino-lab4-clickhouse clickhouse-client -q "SELECT * FROM reports.rpt_sales_by_product LIMIT 5"
```

DBeaver: Trino `jdbc:trino://localhost:18080`, Postgres `localhost:15432` user postgres password password db lab_db, ClickHouse `localhost:18123` default user без пароля. SQL из `trino/sql/` можно открыть и выполнить как скрипт по порядку 01 → 02 → 03.


## Структура репозитория

```text
BigDataTrino/
├── docker-compose.yml
├── GUIDE.md
├── README.md
├── init/postgres/     # создание mock_data + COPY пяти csv в postgres
├── init/clickhouse/    # 00/01 sql под default.mock_data, загрузка csv задаётся в compose у clickhouse-init
├── trino/etc/          # config + catalog postgresql + clickhouse
├── trino/sql/          # 01 DDL dwh, 02 измерения+факт+stg, 03 шесть отчётных таблиц
└── data/               # 10 csv
```


## Что в итоге должно быть

В ClickHouse база `dwh`: измерения, `fact_sales`, вспомогательная `stg_raw_union` (объединённое сырьё).

База `reports`: шесть таблиц `rpt_*` с витринами по заданию (разные срезы в одной таблице через колонку `report_section`, где так задумано).

Повторный прогон ETL: снова выполнить 01, потом 02, потом 03. Если порты на хосте менялись в compose — подставить свои в команды и в jdbc.
