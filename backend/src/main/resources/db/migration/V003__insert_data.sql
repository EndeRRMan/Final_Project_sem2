INSERT INTO product (id, name, picture_url, price)
VALUES
    (1, 'Сливочная', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/6.jpg', 320.00),
    (2, 'Особая', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/5.jpg', 179.00),
    (3, 'Молочная', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/4.jpg', 225.00),
    (4, 'Нюренбергская', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/3.jpg', 315.00),
    (5, 'Мюнхенская', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/2.jpg', 330.00),
    (6, 'Русская', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/1.jpg', 189.00);

INSERT INTO orders (id, status, date_created)
SELECT
    i,
    (ARRAY['pending', 'shipped', 'cancelled'])[floor(random() * 3 + 1)],
    CURRENT_DATE - floor(random() * 90)::integer
FROM generate_series(1, 10000) AS s(i);

INSERT INTO order_product (quantity, order_id, product_id)
SELECT
    floor(1 + random() * 50)::integer,
    i,
    1 + floor(random() * 6)::integer % 6
FROM generate_series(1, 10000) AS s(i);

SELECT setval(
    pg_get_serial_sequence('product', 'id'),
    (SELECT max(id) FROM product),
    true
);

SELECT setval(
    pg_get_serial_sequence('orders', 'id'),
    (SELECT max(id) FROM orders),
    true
);

ANALYZE product;
ANALYZE orders;
ANALYZE order_product;
