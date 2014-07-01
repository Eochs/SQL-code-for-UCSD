-- "first precomputation program"

-- create the precomputed tables and insert data from the database
-- project requirements:
-- 1) CREATE TABLE all the precomputed tables of the lattice.
-- 2) Load the precomputed tables with the appropriate data, via
-- INSERT commands. In particular, given the Sales table, write a
-- “first precomputation” program that will insert data in the
-- precomputed tables efficiently.

-- Create big table with all columns (at bottom of the lattice)
-- users, products, amt

-- test

DROP TABLE IF EXISTS pc_Big;
DROP TABLE IF EXISTS pc_StateProd;
DROP TABLE IF EXISTS pc_UseCat;
DROP TABLE IF EXISTS pc_StateCat;
DROP TABLE IF EXISTS pc_Users;
DROP TABLE IF EXISTS pc_Prod;
DROP TABLE IF EXISTS pc_All;
DROP TABLE IF EXISTS pc_state;
DROP TABLE IF EXISTS pc_cat;
DROP TABLE IF EXISTS pc_Prod_Limit;

CREATE TABLE pc_Big (
  uid INT, --id of user
  pid INT, -- id of product
  use_prod_amt INT -- amount * price at the time of sale
);

/*
INSERT INTO pc_Big
SELECT users.id, products.id, sales.quantity * sales.price AS amt
FROM users, products, sales
WHERE users.id = sales.uid
AND sales.pid = products.id ;
*/
INSERT INTO pc_Big
SELECT users.id, products.id, COALESCE(sales.quantity * sales.price, 0) AS amt
FROM (users LEFT OUTER JOIN sales ON users.id = sales.uid) 
     RIGHT OUTER JOIN products ON sales.pid = products.id ;


-- state, products
CREATE TABLE pc_StateProd (
  st_name TEXT,
  prod_id INT,
  st_prod_amt INT
);



/*
INSERT INTO pc_StateProd
SELECT users.state, pc_Big.pid, SUM(pc_Big.use_prod_amt)
FROM users, pc_Big
WHERE users.id = pc_Big.uid
GROUP BY users.state, pc_Big.pid;
*/
INSERT INTO pc_StateProd
SELECT users.state, products.id, COALESCE(sum(sales.quantity * sales.price), 0)
FROM users
LEFT OUTER JOIN sales ON users.id = sales.uid
RIGHT OUTER JOIN products ON sales.pid = products.id
GROUP BY users.state, products.id;

-- users, categories
CREATE TABLE pc_UseCat (
  uid INT,
  cid INT,
  use_cat_amt INT
);

INSERT INTO pc_UseCat
SELECT pc_Big.uid, products.cid, SUM(pc_Big.use_prod_amt)
FROM products, pc_Big
WHERE products.id = pc_Big.pid
GROUP BY pc_Big.uid, products.cid;

-- state, categories
CREATE TABLE pc_StateCat (
  st_name TEXT,
  cid INT,
  st_cat_amt INT
);

INSERT INTO pc_StateCat
SELECT pc_StateProd.st_name, products.cid, SUM(pc_StateProd.st_prod_amt)
FROM products, pc_StateProd -- use StateProd since O(50k rows) vs UseCat with O(200k rows)
WHERE pc_StateProd.prod_id = products.id -- join to get categories
GROUP BY pc_StateProd.st_name, products.cid; -- should work


-- users
CREATE TABLE pc_Users (
  uid INT,
  name TEXT,
  amt INT
);

/*INSERT INTO pc_Users
SELECT pc_UseCat.uid, SUM(pc_UseCat.use_cat_amt)
FROM pc_UseCat
GROUP BY pc_UseCat.uid -- sum over categories
LIMIT 20;*/

INSERT INTO pc_Users
SELECT users.id, users.name, COALESCE(sum(sales.quantity * sales.price), 0) as amt
FROM users left outer join sales 
on sales.uid = users.id 
group by users.id 
order by amt desc;




-- products
CREATE TABLE pc_Prod (
  pid INT,
  name TEXT,
  prod_amt INT
);

INSERT INTO pc_Prod
SELECT products.id, products.name, COALESCE(sum(sales.quantity * sales.price), 0) AS prod_amt
FROM products LEFT OUTER JOIN sales ON products.id = sales.pid
GROUP BY products.id ORDER BY prod_amt DESC;

/*INSERT INTO pc_Prod
SELECT pc_StateProd.prod_id, SUM(pc_StateProd.st_prod_amt)
FROM pc_StateProd
GROUP BY pc_StateProd.prod_id; -- sum over states*/

-- new temp for col header names
CREATE TABLE pc_Prod_Limit (
  pid INT,
  name TEXT,
  prod_amt INT
);

INSERT INTO pc_Prod_Limit
SELECT pc_StateProd.prod_id, products.name, SUM(pc_StateProd.st_prod_amt) as prod_amt
FROM pc_StateProd, products
WHERE pc_StateProd.prod_id = products.id
GROUP BY pc_StateProd.prod_id, products.name -- sum over states
ORDER BY prod_amt DESC LIMIT 10;



-- state
CREATE TABLE pc_State (
  st_name TEXT,
  st_amt INT
);

INSERT INTO pc_State
SELECT pc_StateCat.st_name, SUM(pc_StateCat.st_cat_amt)
FROM pc_StateCat
GROUP BY pc_StateCat.st_name; -- sum over categories


-- categories
CREATE TABLE pc_Cat (
  cid INT,
  cat_amt INT
);

INSERT INTO pc_Cat
SELECT pc_StateCat.cid, SUM(pc_StateCat.st_cat_amt)
FROM pc_StateCat
GROUP BY pc_StateCat.cid; -- sum over states


-- all
CREATE TABLE pc_All (
  all_amt INT
);

INSERT INTO pc_All
SELECT SUM(pc_Cat.cat_amt)
FROM pc_Cat;
-- chose sum over categories since 20 categories < 50 states
-- if number of categories gets > 50 would switch to using pc_State

DROP TABLE IF EXISTS new_table; 
CREATE TABLE new_table as (select users.id as uid, products.id as pid, pc_users.amt as total, pc_Prod.prod_amt as prod_total 
                           from users, products, pc_users, pc_Prod 
                           WHERE users.id = pc_users.uid 
                           and pc_Prod.pid = products.id 
                           group by users.id, products.id, pc_users.amt, pc_Prod.prod_amt 
                           order by pc_users.amt desc, pc_Prod.prod_amt desc);


DROP TABLE IF EXISTS pc_cust00; 
CREATE TABLE pc_cust00 as (select n.uid, n.pid, n.total, n.prod_total, coalesce(sum(sales.price * sales.quantity), 0) as amt  
                          from new_table as n 
                          left outer join sales 
                          on n.uid = sales.uid 
                          and n.pid = sales.pid 
                          group by n.uid, n.pid, n.total, n.prod_total 
                          order by n.total, n.uid, n.pid);


--CASE 01
DROP TABLE IF EXISTS temp_UseCatAmt1;
CREATE TABLE temp_UseCatAmt1 as (select users.id as uid, users.name as name, categories.id as cid from users, categories group by users.id, users.name, categories.id);

DROP TABLE IF EXISTS temp_UseCatAmt2;
CREATE TABLE temp_UseCatAmt2 as (select t1.uid, t1.name, t1.cid, coalesce(sum(sales.price * sales.quantity), 0) as amt from temp_UseCatAmt1 as t1, sales, products, categories where sales.pid = products.id and categories.id = products.cid and t1.uid = sales.uid and t1.cid = categories.id group by t1.uid, t1.name, t1.cid );

--list us users in case 01
DROP TABLE IF EXISTS pc_UseCatAmt;
CREATE TABLE pc_UseCatAmt as (select t1.uid, t1.name, t1.cid, coalesce(t2.amt, 0) as amt from temp_UseCatAmt1 AS t1 LEFT OUTER JOIN temp_UseCatAmt2 AS t2 ON t1.uid = t2.uid and t1.cid = t2.cid );

--generate every product with every category
DROP TABLE IF EXISTS temp_ProdCatAmt1;
CREATE TABLE temp_ProdCatAmt1 as (select products.id as pid, products.name as name, categories.id as cid from products, categories group by products.id, products.name, categories.id);

--list of products in case 01
DROP TABLE IF EXISTS pc_ProdCatAmt;
CREATE TABLE pc_ProdCatAmt as (select t1.pid, t1.name, t1.cid, coalesce(sum(sales.price * sales.quantity), 0) as prod_amt from temp_ProdCatAmt1 as t1, sales, products, categories where sales.pid = products.id and categories.id = products.cid and t1.pid = sales.pid and t1.cid = categories.id group by t1.pid, t1.name, t1.cid);
-------------------------------------------------------------------------------------------------------------------------------

--select * from temp_ProdCatAmt1;
/*DROP TABLE IF EXISTS pc_ProdCatAmt;
CREATE TABLE pc_ProdCatAmt as (select t1.pid, t1.name, t1.cid, coalesce(t2.amt, 0) as prod_amt from temp_ProdCatAmt1 AS t1 LEFT OUTER JOIN temp_ProdCatAmt2 AS t2 ON t1.pid = t2.pid and t1.cid = t2.cid);*/
------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS temp_cust01; 
/*CREATE TABLE temp_cust01 as (select users.id as uid, products.id as pid, pc_UseCatAmt.amt as total, pc_ProdCatAmt.prod_amt as prod_total 
                           from users, products, pc_UseCatAmt, pc_ProdCatAmt 
                           WHERE users.id = pc_UseCatAmt.uid 
                           and pc_ProdCatAmt.pid = products.id 
                           group by users.id, products.id, pc_UseCatAmt.amt, pc_ProdCatAmt.prod_amt 
                           order by pc_UseCatAmt.amt desc, pc_ProdCatAmt.prod_amt desc);*/


DROP TABLE IF EXISTS pc_cust01; 
CREATE TABLE pc_cust01 as (select n.uid, n.pid, n.total, n.prod_total, coalesce(sum(sales.price * sales.quantity), 0) 
                          from temp_cust01 as n 
                          left outer join sales 
                          on n.uid = sales.uid 
                          and n.pid = sales.pid 
                          group by n.uid, n.pid, n.total, n.prod_total 
                          order by n.total, n.uid, n.pid);





