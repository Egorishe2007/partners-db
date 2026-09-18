-- Проверка, что данные импортировались полностью и без нарушений связей.

-- Количество строк в каждой таблице.
SELECT 'partner' AS table_name, COUNT(*) AS row_count FROM partner
UNION ALL
SELECT 'product', COUNT(*) FROM product
UNION ALL
SELECT 'delivery', COUNT(*) FROM delivery
ORDER BY table_name;

-- Отгрузок без партнера или без продукции быть не должно.
SELECT COUNT(*) AS orphan_delivery_count
FROM delivery AS d
LEFT JOIN partner AS p ON p.partner_id = d.partner_id
LEFT JOIN product AS pr ON pr.product_id = d.product_id
WHERE p.partner_id IS NULL
   OR pr.product_id IS NULL;

-- Даты и суммы после очистки: границы периода и общая сумма отгрузок.
SELECT MIN(delivery_date) AS first_delivery,
       MAX(delivery_date) AS last_delivery,
       SUM(total_amount) AS deliveries_amount
FROM delivery;
