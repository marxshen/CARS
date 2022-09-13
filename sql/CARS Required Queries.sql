/* Retrieval Queries */
/* 1. Find a customer who did not get Service A for a particular car on time */
WITH chosen_derived_type AS (SELECT 'A')

SELECT cars.customer_id,
       customers.name
FROM customers
     INNER JOIN cars
     ON customers.id = cars.customer_id
WHERE cars.license_plate_number NOT IN (
    SELECT license_plate_number
    FROM service_history
    WHERE service_type = (SELECT * FROM chosen_derived_type)
);

/* 2. Find a customer who has not get any of his cars serviced */
WITH chosen_derived_type AS (SELECT '')

SELECT cars.customer_id,
       customers.name
FROM customers 
     INNER JOIN cars
     ON customers.id = cars.customer_id
WHERE cars.latest_service_type = (SELECT * FROM chosen_derived_type);

/* 3. Find the most frequently used part at the current location */
WITH chosen_center_id AS (SELECT 'S0001'),

serv_hst AS (
    SELECT cars.maker,
           cars.model,
           serv_hst.service_type
    FROM service_history AS serv_hst
         INNER JOIN cars
         ON serv_hst.license_plate_number = cars.license_plate_number
         WHERE serv_hst.service_center_id = (SELECT * FROM chosen_center_id)
),
servs AS (
    SELECT serv_hst.maker,
           serv_hst.model,
           maint_servs.basic_service
    FROM maintenance_services AS maint_servs
         INNER JOIN serv_hst
         ON maint_servs.maker = serv_hst.maker
            AND maint_servs.model = serv_hst.model
            AND maint_servs.type = serv_hst.service_type
    UNION ALL (
        SELECT serv_hst.maker,
               serv_hst.model,
               repr_servs.basic_service
        FROM repair_services AS repr_servs
             INNER JOIN serv_hst
             ON repr_servs.diagnostic = serv_hst.service_type
    )
),
ba_servs AS (
    SELECT ba_servs.part_id
    FROM basic_services AS ba_servs
         INNER JOIN servs
         ON ba_servs.maker = servs.maker
            AND ba_servs.model = servs.model
            AND ba_servs.name = servs.basic_service
),
parts AS (
    SELECT parts.name AS part_name,
           parts.maker,
           COUNT(parts.name) AS car_count
    FROM parts
         INNER JOIN ba_servs
         ON parts.id = ba_servs.part_id
         GROUP BY parts.name, parts.maker
)

SELECT part_name,
       maker,
       car_count AS highest_car_count
FROM parts
WHERE car_count = (
    SELECT MAX(car_count)
    FROM parts
)

/* 4. Find the make/model of the car that is repaired most often */
WITH chosen_base_type AS (SELECT 'Repair'),

serv_hst AS (
    SELECT cars.maker,
           cars.model,
           COUNT(cars.model) AS car_count
    FROM service_history AS serv_hst
         INNER JOIN cars
         ON serv_hst.license_plate_number = cars.license_plate_number
         INNER JOIN service_types AS serv_typs
         ON serv_hst.service_type = serv_typs.derived_type
    WHERE serv_typs.base_type = (SELECT * FROM chosen_base_type)
    GROUP BY maker,
             model
)

SELECT maker,
       model,
       car_count AS highest_car_count
FROM serv_hst
WHERE car_count = (
    SELECT MAX(car_count)
    FROM serv_hst
);

/* 5. Find the distributor with the maximum quantity of part Air Filter with minimum delivery window */
WITH chosen_part_name AS (SELECT 'Air Filter'),

serv_ctr_inv AS (
    SELECT serv_ctr_inv.service_center_id,
           parts.name AS part_name,
           parts.maker,
           serv_ctr_inv.delivery_window,
           serv_ctr_inv.current_quantity
    FROM service_center_inventory AS serv_ctr_inv
         INNER JOIN parts
         ON serv_ctr_inv.part_id = parts.id
    WHERE parts.name = (SELECT * FROM chosen_part_name)
),
minimum_delivery_window AS (
    SELECT *
    FROM serv_ctr_inv
    WHERE delivery_window = (
              SELECT MIN(delivery_window)
              FROM serv_ctr_inv
          )
)

SELECT *
FROM minimum_delivery_window
WHERE current_quantity = (
          SELECT MAX(current_quantity)
          FROM minimum_delivery_window
      );

/* 6. Find the mechanic with the most number of labor hours at each service center of Acme corporation */
WITH serv_hst AS (
    SELECT serv_hst.service_center_id, 
           serv_hst.mechanic_name,
           cars.maker,
           cars.model,
           serv_hst.service_type
    FROM service_history AS serv_hst
         INNER JOIN cars
         ON serv_hst.license_plate_number = cars.license_plate_number         
),
servs AS (
    SELECT serv_hst.service_center_id,
		   serv_hst.mechanic_name,
		   serv_hst.maker,
		   serv_hst.model,
		   maint_servs.basic_service
    FROM maintenance_services AS maint_servs
         INNER JOIN serv_hst
         ON maint_servs.maker = serv_hst.maker
            AND maint_servs.model = serv_hst.model
            AND maint_servs.type = serv_hst.service_type
    UNION ALL (
        SELECT serv_hst.service_center_id,
			   serv_hst.mechanic_name,
			   serv_hst.maker,
		   	   serv_hst.model,
			   repr_servs.basic_service
        FROM repair_services AS repr_servs 
             INNER JOIN serv_hst
             ON repr_servs.diagnostic = serv_hst.service_type
    )
),
ba_servs AS (
    SELECT servs.service_center_id,
           servs.mechanic_name,
           SUM(ba_servs.required_hours) AS total_required_hours
    FROM basic_services AS ba_servs
         INNER JOIN servs
         ON ba_servs.maker = servs.maker
            AND ba_servs.model = servs.model
            AND ba_servs.name = servs.basic_service
	GROUP BY servs.service_center_id,
             servs.mechanic_name
),
mechanics AS (
    SELECT service_center_id,
           mechanic_name AS name,
           SUM(total_required_hours) AS total_service_hours
    FROM ba_servs
    GROUP BY service_center_id,
             mechanic_name
)

SELECT *
FROM mechanics
WHERE total_service_hours IN (
    SELECT MAX(total_service_hours)
    FROM mechanics
    GROUP BY service_center_id
);

/* Reporting Queries */
/* 1. Generate an invoice for the most recent service for a customer */
WITH chosen_customer_id AS (SELECT '1003'),
     end_date AS (SELECT '5-Nov-2016'::date),

customer AS (
    SELECT customer_id AS id,
           MAX(service_date) AS latest_service_date
    FROM service_history
    WHERE customer_id = (SELECT * FROM chosen_customer_id)
          AND service_date <= (SELECT * FROM end_date)
    GROUP BY customer_id
),
serv_hst AS (
    SELECT cars.maker,
           cars.model,
           serv_hst.service_type
    FROM service_history AS serv_hst
         INNER JOIN customer
         ON serv_hst.customer_id = customer.id
            AND serv_hst.service_date = customer.latest_service_date
         INNER JOIN cars
         ON serv_hst.license_plate_number = cars.license_plate_number
),
servs AS (    
    SELECT serv_hst.maker,
           serv_hst.model,
           maint_servs.basic_service
    FROM maintenance_services AS maint_servs
         INNER JOIN serv_hst
         ON maint_servs.maker = serv_hst.maker
            AND maint_servs.model = serv_hst.model
            AND maint_servs.type = serv_hst.service_type
         UNION ALL (
             SELECT serv_hst.maker,
                    serv_hst.model,
                    repr_servs.basic_service
             FROM repair_services AS repr_servs
                  INNER JOIN serv_hst
                  ON repr_servs.diagnostic = serv_hst.service_type
         )
),
wnty_hst AS (
    SELECT part_id
    FROM warranty_history
    WHERE service_date < (SELECT latest_service_date FROM customer)
          AND expiration_date >= (SELECT latest_service_date FROM customer)
),
ba_servs AS (
    SELECT parts.name AS part_name,
           parts.price,
           ba_servs.required_hours,
           labor_charges.rate
               * ba_servs.required_hours
               + parts.price
               * ba_servs.quantity
               * (NOT EXISTS(
                      SELECT 1 FROM wnty_hst WHERE wnty_hst.part_id = ba_servs.part_id
                 ))::int AS required_cost

    FROM basic_services AS ba_servs
         INNER JOIN servs
         ON ba_servs.maker = servs.maker
            AND ba_servs.model = servs.model
            AND ba_servs.name = servs.basic_service
         INNER JOIN labor_charges
         ON ba_servs.labor_charge_type = labor_charges.type 
         INNER JOIN parts
         ON ba_servs.part_id = parts.id
),
total_required_hours AS (
    SELECT SUM(required_hours) AS hours
    FROM ba_servs
),
total_service_time AS (    
    SELECT trunc(hours)::int AS hours,
           (hours - trunc(hours))::float * 60 AS minutes
    FROM total_required_hours
)

SELECT serv_hst.id AS service_id,
       serv_hst.service_date,
       serv_hst.starting_time,
       (serv_hst.starting_time
            + interval '1 h' * (SELECT hours FROM total_service_time)
            + interval '1 m' * (SELECT minutes FROM total_service_time)
       ) AS end_time,
       serv_hst.license_plate_number,
       concat(
           (SELECT base_type FROM service_types WHERE derived_type = serv_hst.service_type),
           ' ',
           serv_hst.service_type
       ) AS service_type,
       serv_hst.mechanic_name,
       (SELECT SUM(required_cost) FROM ba_servs) AS total_service_cost

FROM service_history AS serv_hst
     INNER JOIN customer
     ON serv_hst.customer_id = customer.id
        AND serv_hst.service_date = customer.latest_service_date

/* 2. Generate an itemized invoice for the most recent service for a customer (540 only) */
WITH chosen_customer_id AS (SELECT '1003'),
     end_date AS (SELECT '5-Nov-2016'::date),

customer AS (
    SELECT customer_id AS id,
           MAX(service_date) AS latest_service_date
    FROM service_history
    WHERE customer_id = (SELECT * FROM chosen_customer_id)
          AND service_date <= (SELECT * FROM end_date)
    GROUP BY customer_id
),
serv_hst AS (
    SELECT cars.maker,
           cars.model,
           serv_hst.service_type
    FROM service_history AS serv_hst
         INNER JOIN customer
         ON serv_hst.customer_id = customer.id
            AND serv_hst.service_date = customer.latest_service_date
         INNER JOIN cars
         ON serv_hst.license_plate_number = cars.license_plate_number
),
servs AS (
    SELECT serv_hst.maker,
           serv_hst.model,
           maint_servs.basic_service
    FROM maintenance_services AS maint_servs
         INNER JOIN serv_hst
         ON maint_servs.maker = serv_hst.maker
            AND maint_servs.model = serv_hst.model
            AND maint_servs.type = serv_hst.service_type
    UNION ALL (
        SELECT serv_hst.maker,
               serv_hst.model,
               repr_servs.basic_service
        FROM repair_services AS repr_servs
             INNER JOIN serv_hst
             ON repr_servs.diagnostic = serv_hst.service_type
    )
),
wnty_hst AS (
    SELECT part_id
    FROM warranty_history
    WHERE service_date < (SELECT latest_service_date FROM customer)
          AND expiration_date >= (SELECT latest_service_date FROM customer)
),
ba_servs AS (
    SELECT parts.name AS part_name,
           parts.price AS part_price,
           ba_servs.quantity AS part_quantity,
           ba_servs.required_hours,
           labor_charges.rate
               * ba_servs.required_hours
               + parts.price
               * ba_servs.quantity
               * (NOT EXISTS(
                      SELECT 1 FROM wnty_hst WHERE wnty_hst.part_id = ba_servs.part_id
                 ))::int AS required_cost

    FROM basic_services AS ba_servs
         INNER JOIN servs
         ON ba_servs.maker = servs.maker
            AND ba_servs.model = servs.model
            AND ba_servs.name = servs.basic_service
         INNER JOIN labor_charges
         ON ba_servs.labor_charge_type = labor_charges.type 
         INNER JOIN parts
         ON ba_servs.part_id = parts.id
),
total_required_hours AS (
    SELECT SUM(required_hours) AS hours
    FROM ba_servs
),
total_service_time AS (
    SELECT trunc(hours)::int AS hours,
           (hours - trunc(hours))::float * 60 AS minutes
    FROM total_required_hours
),
used_part_catelogue AS (
    SELECT array_agg(part_name) AS names,
           array_agg(part_price) AS costs,
           array_agg(part_quantity) AS units
    FROM ba_servs
)

SELECT serv_hst.id AS service_id,
       serv_hst.service_date,
       serv_hst.starting_time,
       (serv_hst.starting_time
            + interval '1 h' * (SELECT hours FROM total_service_time)
            + interval '1 m' * (SELECT minutes FROM total_service_time)
       ) AS end_time,
       serv_hst.license_plate_number,
       concat(
           (SELECT base_type FROM service_types WHERE derived_type = serv_hst.service_type),
           ' ',
           serv_hst.service_type
       ) AS service_type,
       serv_hst.mechanic_name,
       (SELECT names FROM used_part_catelogue) AS used_part_names,
       (SELECT costs FROM used_part_catelogue) AS used_part_costs,
       (SELECT units FROM used_part_catelogue) AS used_part_units,
       (SELECT SUM(required_cost) FROM ba_servs) AS total_service_cost

FROM service_history AS serv_hst
     INNER JOIN customer
     ON serv_hst.customer_id = customer.id
        AND serv_hst.service_date = customer.latest_service_date

/* 3. For each location, show the average number of cars serviced per day */
WITH serv_hst AS (
    SELECT service_center_id,
           service_date,
           COUNT(license_plate_number) AS daily_car_count
    FROM service_history
    GROUP BY service_center_id,
             service_date
)

SELECT service_center_id,
       AVG(daily_car_count)::float AS average_daily_car_count
FROM serv_hst
GROUP BY service_center_id

/* 4. For each mechanic, show the average number of hours worked per week */
WITH serv_hst AS (
    SELECT serv_hst.mechanic_name,
           date_trunc('week', serv_hst.service_date::timestamp) AS service_week,
           cars.maker,
           cars.model,
           serv_hst.service_type
    FROM service_history AS serv_hst
         INNER JOIN cars
         ON serv_hst.license_plate_number = cars.license_plate_number
),
servs AS (
    SELECT serv_hst.mechanic_name,
		   serv_hst.service_week,
		   serv_hst.maker,
           serv_hst.model,
           maint_servs.basic_service
    FROM maintenance_services AS maint_servs
         INNER JOIN serv_hst
         ON maint_servs.maker = serv_hst.maker
            AND maint_servs.model = serv_hst.model
            AND maint_servs.type = serv_hst.service_type
    UNION ALL (
        SELECT serv_hst.mechanic_name,
			   serv_hst.service_week,
			   serv_hst.maker,
               serv_hst.model,
               repr_servs.basic_service
        FROM repair_services AS repr_servs
             INNER JOIN serv_hst
             ON repr_servs.diagnostic = serv_hst.service_type
    )
),
ba_servs AS (
    SELECT servs.mechanic_name,
           servs.service_week,
           SUM(ba_servs.required_hours) AS weekly_service_hours
    FROM basic_services AS ba_servs
	INNER JOIN servs
    ON ba_servs.maker = servs.maker
       AND ba_servs.model = servs.model
       AND ba_servs.name = servs.basic_service
    GROUP BY servs.mechanic_name,
             servs.service_week
)

SELECT mechanic_name,
       AVG(weekly_service_hours)::real AS average_weekly_service_hours
FROM ba_servs
GROUP BY mechanic_name

/* 5. For each service, show the average number of miles that a car is driven before receiving that service.
      Do this across all service centers. (For 540 - Also do this per service center) */

/* Across all service centers */
SELECT cars.latest_service_type,
       AVG(cars.last_recorded_mileage)::float AS average_recorded_mileage
FROM cars
     INNER JOIN service_history AS serv_hst
     ON cars.license_plate_number = serv_hst.license_plate_number
        AND cars.latest_service_type = serv_hst.service_type
GROUP BY cars.latest_service_type

/* Per service center */
SELECT serv_hst.service_center_id,
       cars.latest_service_type,
       AVG(cars.last_recorded_mileage)::float AS average_recorded_mileage
FROM cars
     INNER JOIN service_history AS serv_hst
     ON cars.license_plate_number = serv_hst.license_plate_number
        AND cars.latest_service_type = serv_hst.service_type
GROUP BY serv_hst.service_center_id,
         cars.latest_service_type

/* 6. Display the current inventory levels at the current location */
WITH chosen_center_id AS (SELECT 'S0001')

SELECT serv_ctr_inv.service_center_id,
       parts.maker,
       parts.name,
       serv_ctr_inv.current_quantity,
       serv_ctr_inv.minimum_inventory_threshold,
       serv_ctr_inv.minimum_order_quantity
FROM service_center_inventory AS serv_ctr_inv
     INNER JOIN parts
     ON serv_ctr_inv.part_id = parts.id
WHERE serv_ctr_inv.service_center_id = (SELECT * FROM chosen_center_id)

/* 7. Find the number of repair requests in past one month which includes a warrantied service */
WITH end_date AS (SELECT '06-Nov-2016'::timestamp),
	 start_date AS (SELECT (SELECT * FROM end_date) - '1 mon'::interval),
	 chosen_base_type AS (SELECT 'Repair'),

serv_hst AS (	
    SELECT cars.license_plate_number,
           cars.maker,
           cars.model,
           repr_servs.basic_service,
		   serv_hst.service_date
    FROM service_history AS serv_hst
         INNER JOIN service_types AS serv_typs
         ON serv_hst.service_type = serv_typs.derived_type
            AND serv_typs.base_type = (SELECT * FROM chosen_base_type)
         INNER JOIN cars
         ON serv_hst.license_plate_number = cars.license_plate_number
         INNER JOIN repair_services AS repr_servs
         ON serv_hst.service_type = repr_servs.diagnostic
),
wnty_hst AS (
    SELECT serv_hst.license_plate_number,
		   serv_hst.service_date,
		   ba_servs.part_id
    FROM serv_hst
         INNER JOIN basic_services AS ba_servs
         ON serv_hst.maker = ba_servs.maker
            AND serv_hst.model = ba_servs.model
            AND serv_hst.basic_service = ba_servs.name
	     INNER JOIN warranty_history AS wnty_hst
		 ON serv_hst.license_plate_number = wnty_hst.license_plate_number
			AND serv_hst.service_date = wnty_hst.service_date
			AND ba_servs.part_id = wnty_hst.part_id
    WHERE wnty_hst.service_date::timestamp < (SELECT * FROM end_date) 
          AND wnty_hst.expiration_date::timestamp >= (SELECT * FROM start_date)
	GROUP BY serv_hst.license_plate_number,
			 serv_hst.service_date,
			 ba_servs.part_id
)

SELECT *
FROM wnty_hst

/* Insert and Update Queries */
/* 1. Create a new user account for the receptionist, and mechanics */
INSERT INTO employees (
                id,
                name,
                address,
                email_address,
                phone_number,
                service_center_id,
                role,
                starting_date,
                compensation,
                payroll_frequency
            ) VALUES
    ('745733348', 'Steven Yeun', '320 The Greens Cir, Raleigh, NC 27606',
     'sryeun@acme.com', '324-099-3122', 'S0001', 'Receptionist', 'October 31, 2010', 10000, 'monthly'),
    ('668380391', 'Norman Reedus', '320 The Greens Cir, Raleigh, NC 27606',
     'noreedus@acme.com', '524-446-0634', 'S0001', 'Mechanics', 'October 16, 2011', 50, 'hourly');

INSERT INTO employee_passwords (employee_id, password) VALUES
    ('745733348', 'RG61040Vepimkl764XliKviirwGmv'),
    ('668380391', 'JY83262Nwhaecd986PdaCnaajoYen');

/* 2. Update profile information (name, address, phone number, and password) for logged in user */
UPDATE employees
   SET (name, address, email_address, phone_number)
     = ('Andrew Lincoln', '320 The Greens Cir, Raleigh, NC 27606', 'anlincoln@@acme.com', '427-089-6505')
 WHERE id = '950932130';

UPDATE employee_passwords
   SET (password)
     = ROW ('QF50939Udohljk653WkhJuhhqvFlu')
 WHERE employee_id = '950932130';

UPDATE customers
   SET (name, address, email_address, phone_number)
     = ('Lauren Cohan', '320 The Greens Cir, Raleigh, NC 27606', 'maggierhee@gmail.com', '9280938200')
 WHERE id = '1001';

UPDATE customer_passwords
   SET (password)
     = ROW ('KZ94373Oxibfde097QebDobbkpZfo')
 WHERE customer_id = '1001';

/* 3. Place orders for new parts */
INSERT INTO orders (
                id,
                order_placement_date,
                expeted_delivery_date,
                actual_delivery_date,
                maker,
                part,
                quantity,
                source_id,
                destination_id,
                order_status
            ) VALUES
('O0012', '09-Nov-2018', '14-Nov-2018', NULL, 'Honda', 'Brake Fluid', 5, 'D0002', 'S0002', 'Pending');

/* 4. Schedule a new service */
INSERT INTO service_history (
                id,
                license_plate_number,
                service_type,
                service_date,
                customer_id,
                service_center_id,
                starting_time,
                mechanic_name
            ) VALUES
('H0017', 'XYZ-5643', 'A', '11-Sep-2018', '1001', 'S0001', '10:00 AM', 'Jacob Gloss');
