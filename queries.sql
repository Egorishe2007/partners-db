-- Проверочные запросы, которые будет выполнять приложение.

SET client_encoding = 'UTF8';

-- 1. Список партнеров по алфавиту и количество сделанных ими отгрузок.
--    LEFT JOIN нужен, чтобы партнер без отгрузок тоже попал в список.
SELECT p.partner_id,
       p.company_name,
       p.inn,
       p.contact_email,
       COUNT(d.delivery_id) AS delivery_count
FROM partner AS p
LEFT JOIN delivery AS d ON d.partner_id = p.partner_id
GROUP BY p.partner_id, p.company_name, p.inn, p.contact_email
ORDER BY p.company_name;

-- 2. Добавление нового партнера и его первой отгрузки одной транзакцией:
--    либо в базе появятся обе записи, либо не появится ни одной.
--    Повторный запуск выдаст ошибку уникальности ИНН — это и означает,
--    что ограничение работает.
BEGIN;

INSERT INTO partner (company_name, inn, contact_email, phone, rating)
VALUES ('ООО "Северный Путь"', '7709998877', 'info@sevput.example',
        '+79995558877', 4.5);

INSERT INTO delivery (partner_id, product_id, delivery_date, quantity,
                      total_amount)
VALUES ((SELECT partner_id FROM partner WHERE inn = '7709998877'),
        (SELECT product_id FROM product
         WHERE product_name = 'Кондиционер для белья'),
        CURRENT_DATE, 25, 8750.00);

UPDATE partner
SET rating = 4.7
WHERE inn = '7709998877';

COMMIT;

-- 3. История отгрузок конкретного партнера за период: название продукции,
--    дата, объем в штуках и сумма поставки. Последний столбец — итог
--    за весь период. Партнер и границы периода задаются в WHERE.
SELECT p.company_name,
       pr.product_name,
       d.delivery_date,
       d.quantity,
       d.total_amount,
       SUM(d.total_amount) OVER () AS period_total
FROM delivery AS d
JOIN partner AS p ON p.partner_id = d.partner_id
JOIN product AS pr ON pr.product_id = d.product_id
WHERE p.partner_id = 1
  AND d.delivery_date BETWEEN DATE '2026-03-01' AND DATE '2026-03-31'
ORDER BY d.delivery_date;
