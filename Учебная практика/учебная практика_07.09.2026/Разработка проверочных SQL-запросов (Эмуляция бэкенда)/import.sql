-- Импорт подготовленных данных в PostgreSQL.
-- Выполняется из корня проекта: psql -U postgres -d partners_db -f import.sql
-- Пути в \copy указаны относительно каталога запуска.

SET client_encoding = 'UTF8';

\copy partner (partner_id, company_name, inn, contact_email, phone, rating) FROM 'data/clean_partner.csv' WITH (FORMAT csv, HEADER true)
\copy product (product_id, product_name) FROM 'data/clean_product.csv' WITH (FORMAT csv, HEADER true)
\copy delivery (delivery_id, partner_id, product_id, delivery_date, quantity, total_amount) FROM 'data/clean_delivery.csv' WITH (FORMAT csv, HEADER true)

-- Идентификаторы пришли из файлов, поэтому счетчики нужно сдвинуть:
-- иначе следующая запись получит уже занятый номер.
SELECT setval(pg_get_serial_sequence('partner', 'partner_id'),
              MAX(partner_id))
FROM partner;

SELECT setval(pg_get_serial_sequence('product', 'product_id'),
              MAX(product_id))
FROM product;

SELECT setval(pg_get_serial_sequence('delivery', 'delivery_id'),
              MAX(delivery_id))
FROM delivery;
