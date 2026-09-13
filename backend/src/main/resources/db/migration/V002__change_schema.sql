ALTER TABLE product
    ADD COLUMN price double precision;

UPDATE product AS p
SET price = pi.price
FROM product_info AS pi
WHERE pi.product_id = p.id;

ALTER TABLE product
    ADD CONSTRAINT product_pkey PRIMARY KEY (id);

ALTER TABLE orders
    ADD COLUMN date_created date DEFAULT CURRENT_DATE;

UPDATE orders AS o
SET date_created = od.date_created
FROM orders_date AS od
WHERE od.order_id = o.id;

ALTER TABLE orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);

ALTER TABLE order_product
    ADD CONSTRAINT order_product_order_id_fkey
        FOREIGN KEY (order_id) REFERENCES orders (id),
    ADD CONSTRAINT order_product_product_id_fkey
        FOREIGN KEY (product_id) REFERENCES product (id);

DROP TABLE product_info;
DROP TABLE orders_date;
