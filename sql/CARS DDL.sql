DROP TABLE IF EXISTS inventories, distributors, service_centers,
                     roles, payroll_frequencies, employees, employee_passwords,
                     makers, models, service_types, cars, customers, customer_passwords,
                     parts, base_basic_services, labor_charges, basic_services,
                     base_maintenance_services, maintenance_services,
                     base_repair_services, repair_services,
                     distributor_inventory, service_center_inventory,
                     service_history, warranty_history,
                     order_status, orders, notifications;

DROP FUNCTION IF EXISTS inventory_constraints(), service_center_constraints(),
                        employee_constraints(), employee_password_constraints(),
                        car_constraints(), customer_constraints(), customer_password_constraints(),
                        part_constraints(), labor_charge_constraints(),
                        basic_service_constraints(),
                        base_maintenance_service_constraints(),
                        base_repair_service_constraints(),
                        distributor_inventory_constraints(),
                        service_center_inventory_constraints(), 
                        service_history_constraints(), warranty_history_constraints,
                        order_constraints(), notification_constraints();

CREATE TABLE inventories (
    id text,
    PRIMARY KEY (id)
);

CREATE FUNCTION inventory_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.id !~ 'S\d{4}|D\d{4}' THEN
                RAISE EXCEPTION 'Illicit ID (%) on TABLE inventories', NEW.id;

            ELSE
                -- This case raises no exception.
        END CASE;
        
        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER inventory_constraints BEFORE INSERT OR UPDATE ON inventories
    FOR EACH ROW EXECUTE FUNCTION inventory_constraints();

--

CREATE TABLE distributors (
    id text,
    name text,
    PRIMARY KEY (id),
    FOREIGN KEY (id) REFERENCES inventories (id) ON DELETE CASCADE,
    CHECK(NOT (name) IS NULL)
);

--

CREATE TABLE service_centers (
    id text,
    name text,
    address text,
    telephone_number text,
    PRIMARY KEY (id),
    FOREIGN KEY (id) REFERENCES inventories (id) ON DELETE CASCADE,
    CHECK(NOT (name, address, telephone_number) IS NULL)
);

CREATE FUNCTION service_center_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.telephone_number !~ '\d.\d{3}.\d{3}.\d{4}' THEN

                RAISE EXCEPTION 'Illicit telephone number (%) on TABLE service_centers',
                                NEW.telephone_number;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;
    
$$ LANGUAGE plpgsql;

CREATE TRIGGER service_center_constraints BEFORE INSERT OR UPDATE ON service_centers
    FOR EACH ROW EXECUTE FUNCTION service_center_constraints();

--

CREATE TABLE roles (
    type text,
    PRIMARY KEY (type)
);

--

CREATE TABLE payroll_frequencies (
    type text,
    PRIMARY KEY (type)
);

--

/* Each service center is managed by one manager, one receptionist and at least five mechanics.
   An employee can work at only one service center. 
*/
CREATE TABLE employees (
    id text,
    name text,
    address text,
    email_address text,
    phone_number text,
    service_center_id text,
    role text,
    starting_date date,
    compensation integer,
    payroll_frequency text,
    PRIMARY KEY (id),
    FOREIGN KEY (service_center_id) REFERENCES service_centers (id) ON DELETE RESTRICT,
    FOREIGN KEY (role) REFERENCES roles (type) ON DELETE RESTRICT,
    FOREIGN KEY (payroll_frequency) REFERENCES payroll_frequencies (type) ON DELETE RESTRICT,
    CHECK (NOT (name, address, email_address, phone_number, starting_date, compensation) IS NULL)
);

CREATE FUNCTION employee_constraints() RETURNS trigger AS $$
    #variable_conflict use_column
    DECLARE
    manager_id text := (SELECT OLD.id
                        FROM employees OLD
                        WHERE OLD.role ~ 'Manager'
                              AND OLD.service_center_id = NEW.service_center_id);

    receptionist_id text := (SELECT OLD.id
                             FROM employees OLD
                             WHERE OLD.role ~ 'Receptionist'
                                   AND OLD.service_center_id = NEW.service_center_id);

    BEGIN
        CASE
            WHEN NEW.id !~ '\d{9}' THEN
                RAISE EXCEPTION 'Illicit ID (%) on TABLE employees', NEW.id;

            WHEN NEW.email_address !~ '[[:alnum:]_]*@acme.com' THEN
                RAISE EXCEPTION 'Illicit email address (%) on TABLE employees', NEW.email_address;

            WHEN NEW.phone_number !~ '\d{3}-\d{3}-\d{4}|\d{10}' THEN
                RAISE EXCEPTION 'Illicit phone number (%) on TABLE employees', NEW.phone_number;

            WHEN NEW.role ~ 'Manager' THEN
                CASE
                    WHEN manager_id IS NOT NULL
                         AND manager_id !~ NEW.id THEN
                        
                        RAISE EXCEPTION 'Duplicate manager (%) on TABLE employees', NEW.name;
                    
                    ELSE
                        -- This case raises no exception.
                END CASE;

            WHEN NEW.role ~ 'Receptionist' THEN
                CASE
                    WHEN receptionist_id IS NOT NULL
                         AND receptionist_id !~ NEW.id THEN
                        
                        RAISE EXCEPTION 'Duplicate receptionist (%) on TABLE employees', NEW.name;
                    
                    ELSE
                        -- This case raises no exception.
                END CASE;

            WHEN NEW.compensation < 0 THEN
                RAISE EXCEPTION 'Negative compensation (%) on TABLE employees', NEW.compensation;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER employee_constraints BEFORE INSERT OR UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION employee_constraints();

--

CREATE TABLE employee_passwords (
    employee_id text,
    password text,
    PRIMARY KEY (employee_id),
    FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
    CHECK(NOT (password) IS NULL)
);

CREATE FUNCTION employee_password_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.password !~ '[[:alnum:]_!@#%&|:.~-]{8,32}' THEN
                RAISE EXCEPTION 'Illicit password (%) on TABLE employee_passwords', NEW.password;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER employee_password_constraints BEFORE INSERT OR UPDATE ON employee_passwords
    FOR EACH ROW EXECUTE FUNCTION employee_password_constraints();

--

CREATE TABLE customers (
    id text,
    name text,
    address text,
    email_address text,
    phone_number text,
    service_center_id text,
    PRIMARY KEY (id),
    UNIQUE (email_address),
    FOREIGN KEY (service_center_id) REFERENCES service_centers (id) ON DELETE RESTRICT,
    CHECK(NOT (name, address, email_address, phone_number) IS NULL)
);

CREATE FUNCTION customer_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.id !~ '\d{4}' THEN
                RAISE EXCEPTION 'Illicit ID (%) on TABLE customers', NEW.id;

            WHEN NEW.email_address !~ '[[:alnum:]_]*@[[:alnum:]_]*.[[:alnum:]_]*' THEN
                RAISE EXCEPTION 'Illicit email address (%) on TABLE customers', NEW.email_address;

            WHEN NEW.phone_number !~ '\d{3}-\d{3}-\d{4}|\d{10}' THEN
                RAISE EXCEPTION 'Illicit phone number (%) on TABLE customers', NEW.phone_number;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER customer_constraints BEFORE INSERT OR UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION customer_constraints();

--

CREATE TABLE customer_passwords (
    customer_id text,
    password text,
    PRIMARY KEY (customer_id),
    FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
    CHECK(NOT (password) IS NULL)
);

CREATE FUNCTION customer_password_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.password !~ '[[:alnum:]_!@#$%&|:.~-]{8,32}' THEN
                RAISE EXCEPTION 'Illicit password (%) on TABLE customer_passwords', NEW.password;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER customer_password_constraints BEFORE INSERT OR UPDATE ON customer_passwords
    FOR EACH ROW EXECUTE FUNCTION customer_password_constraints();

--

CREATE TABLE makers (
    name text,
    PRIMARY KEY (name)
);

--

CREATE TABLE models (
    name text,
    maker text,
    PRIMARY KEY (name, maker),
    FOREIGN KEY (maker) REFERENCES makers (name) ON DELETE RESTRICT
);

--

CREATE TABLE service_types (
    derived_type text,
    base_type text,
    PRIMARY KEY (derived_type),
    CHECK(NOT (base_type) IS NULL)
);

--

CREATE TABLE cars (
    license_plate_number text,
    maker text,
    model text,
    manufacture_year integer,
    customer_id text,
    purchase_date date, 
    last_recorded_mileage integer,
    latest_service_type text,
    latest_service_date date,
    PRIMARY KEY (license_plate_number),
    FOREIGN KEY (model, maker) REFERENCES models (name, maker) ON DELETE RESTRICT,
    FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE RESTRICT,
    FOREIGN KEY (latest_service_type) REFERENCES service_types (derived_type) ON DELETE RESTRICT,
    CHECK(NOT (manufacture_year, purchase_date) IS NULL)
);

CREATE FUNCTION car_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.license_plate_number !~ '[[:alnum:]]{3}-[[:alnum:]]{4}' THEN

                RAISE EXCEPTION 'Illicit license plate number (%) on TABLE cars',
                                NEW.license_plate_number;

            WHEN NEW.manufacture_year < 1886 OR NEW.manufacture_year > 2022 THEN

                RAISE EXCEPTION 'Illicit manufacture year (%) on TABLE cars',
                                NEW.manufacture_year;

            WHEN NEW.last_recorded_mileage IS NOT NULL
                 AND NEW.last_recorded_mileage < 0 THEN

                RAISE EXCEPTION 'Negative recorded mileage (%) on TABLE cars',
                                NEW.last_recorded_mileage;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER car_constraints BEFORE INSERT OR UPDATE ON cars
    FOR EACH ROW EXECUTE FUNCTION car_constraints();

--

CREATE TABLE parts (
    id text,
    name text,
    maker text,
    price integer,
    warranty integer,
    PRIMARY KEY (id),
    FOREIGN KEY (maker) REFERENCES makers (name) ON DELETE RESTRICT,
    CHECK(NOT (name, price) IS NULL)
);

CREATE FUNCTION part_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.id !~ 'P\d{4}' THEN
                RAISE EXCEPTION 'Illicit ID (%) on TABLE parts', NEW.id;

            WHEN NEW.price < 0 THEN
                RAISE EXCEPTION 'Negative price (%) on TABLE parts', NEW.price;

            WHEN NEW.warranty IS NOT NULL
                 AND NEW.warranty < 0 THEN

                RAISE EXCEPTION 'Negative warranty: %', NEW.warranty;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER part_constraints BEFORE INSERT OR UPDATE ON parts
    FOR EACH ROW EXECUTE FUNCTION part_constraints();

--

CREATE TABLE base_basic_services (
    name text,
    PRIMARY KEY (name)
);

--

CREATE TABLE labor_charges (
    type text,
    rate integer,
    PRIMARY KEY (type),
    CHECK(NOT (rate) IS NULL)
);

CREATE FUNCTION labor_charge_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.type !~ 'low|high' THEN
                RAISE EXCEPTION 'Illicit type (%) on TABLE labor_charges',  NEW.type;

            WHEN NEW.rate < 0 THEN
                RAISE EXCEPTION 'Negative rate (%) on TABLE labor_charges',  NEW.rate;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER labor_charge_constraints BEFORE INSERT OR UPDATE ON labor_charges
    FOR EACH ROW EXECUTE FUNCTION labor_charge_constraints();

--

/* Any service provided for the first time will be charged only for the parts. */
CREATE TABLE basic_services (
    name text,
    maker text,
    model text,
    labor_charge_type text,
    required_hours real,
    part_id text,
    quantity integer,
    PRIMARY KEY (name, maker, model),
    FOREIGN KEY (name) REFERENCES base_basic_services (name) ON DELETE CASCADE,
    FOREIGN KEY (model, maker) REFERENCES models (name, maker) ON DELETE CASCADE,
    FOREIGN KEY (labor_charge_type) REFERENCES labor_charges (type) ON DELETE RESTRICT,
    FOREIGN KEY (part_id) REFERENCES parts (id) ON DELETE RESTRICT,
    CHECK(NOT (required_hours, quantity) IS NULL)
);

CREATE FUNCTION basic_service_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.required_hours < 0.0 THEN

                RAISE EXCEPTION 'Negative required hours (%) on TABLE basic_services',
                                NEW.required_hours;

            WHEN NEW.quantity < 0 THEN

                RAISE EXCEPTION 'Negative quantity (%) on TABLE basic_services',
                                NEW.quantity;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER basic_service_constraints BEFORE INSERT OR UPDATE ON basic_services
    FOR EACH ROW EXECUTE FUNCTION basic_service_constraints();

--

CREATE TABLE base_maintenance_services (
    maker text,
    model text,
    type text,
    millage_threshold integer,
    PRIMARY KEY (maker, model, type),
    FOREIGN KEY (model, maker) REFERENCES models (name, maker) ON DELETE CASCADE,
    FOREIGN KEY (type) REFERENCES service_types (derived_type) ON DELETE CASCADE,
    CHECK(NOT (millage_threshold) IS NULL)
);

CREATE FUNCTION base_maintenance_service_constraints() RETURNS trigger AS $$
    #variable_conflict use_column

    BEGIN
        CASE
            WHEN EXISTS(
                     SELECT 1
                     FROM service_types OLD
                     WHERE OLD.derived_type = NEW.type 
                           AND OLD.base_type !~ 'Maintenance'
                 ) THEN
                
                 RAISE EXCEPTION
                    'Illicit type (%) on TABLE base_maintenance_services',
                    NEW.type;
            
            WHEN NEW.millage_threshold < 0 THEN

                RAISE EXCEPTION
                    'Negative millage threshold (%) on TABLE base_maintenance_services',
                    NEW.millage_threshold;
            
            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

 $$ LANGUAGE plpgsql;

CREATE TRIGGER base_maintenance_service_constraints BEFORE INSERT OR UPDATE ON base_maintenance_services
    FOR EACH ROW EXECUTE FUNCTION base_maintenance_service_constraints();

--

CREATE TABLE maintenance_services (
    maker text,
    model text,
    type text,
    basic_service text,
    PRIMARY KEY (maker, model, type, basic_service),
    FOREIGN KEY (maker, model, type) REFERENCES base_maintenance_services ON DELETE CASCADE,
    FOREIGN KEY (basic_service) REFERENCES base_basic_services (name) ON DELETE CASCADE
);

--

CREATE TABLE base_repair_services (
    diagnostic text,
    cause text,
    diagnostic_fee integer,
    PRIMARY KEY (diagnostic),
    FOREIGN KEY (diagnostic) REFERENCES service_types (derived_type) ON DELETE CASCADE,
    CHECK(NOT (cause, diagnostic_fee) IS NULL)
);

CREATE FUNCTION base_repair_service_constraints() RETURNS trigger AS $$
    #variable_conflict use_column

    BEGIN
        CASE
            WHEN EXISTS(
                     SELECT 1
                     FROM service_types OLD
                     WHERE OLD.derived_type = NEW.diagnostic
                           AND OLD.base_type !~ 'Repair'
                 ) THEN

                RAISE EXCEPTION 'Illicit diagnostic (%) on TABLE base_repair_services',
                                NEW.diagnostic;

            WHEN NEW.diagnostic_fee < 0 THEN

                RAISE EXCEPTION 'Negative diagnostic fee (%) on TABLE base_repair_services',
                                NEW.diagnostic_fee;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER base_repair_service_constraints BEFORE INSERT OR UPDATE ON base_repair_services
    FOR EACH ROW EXECUTE FUNCTION base_repair_service_constraints();

--

CREATE TABLE repair_services (
    diagnostic text,
    basic_service text,
    PRIMARY KEY (diagnostic, basic_service),
    FOREIGN KEY (diagnostic) REFERENCES base_repair_services ON DELETE CASCADE,
    FOREIGN KEY (basic_service) REFERENCES base_basic_services (name) ON DELETE CASCADE
);

--

CREATE TABLE distributor_inventory (
    maker text,
    part_id text,
    distributor_id text,
    delivery_window integer,
    PRIMARY KEY (maker, part_id, distributor_id),
    FOREIGN KEY (maker) REFERENCES makers (name) ON DELETE CASCADE,
    FOREIGN KEY (part_id) REFERENCES parts (id) ON DELETE CASCADE,
    FOREIGN KEY (distributor_id) REFERENCES distributors (id) ON DELETE CASCADE
);

CREATE FUNCTION distributor_inventory_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.delivery_window IS NOT NULL
                 AND NEW.delivery_window < 0 THEN

                RAISE EXCEPTION 'Negative delivery window (%) on TABLE distributor_inventory',
                                NEW.delivery_window;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER distributor_inventory_constraints BEFORE INSERT OR UPDATE ON distributor_inventory
    FOR EACH ROW EXECUTE FUNCTION distributor_inventory_constraints();

--

CREATE TABLE service_center_inventory (
    maker text,
    part_id text,
    service_center_id text,
    delivery_window integer,
    current_quantity integer,
    minimum_inventory_threshold integer,
    minimum_order_quantity integer,
    PRIMARY KEY (maker, part_id, service_center_id),
    FOREIGN KEY (maker) REFERENCES makers (name) ON DELETE CASCADE,
    FOREIGN KEY (part_id) REFERENCES parts (id) ON DELETE CASCADE,
    FOREIGN KEY (service_center_id) REFERENCES service_centers (id) ON DELETE CASCADE,
    CHECK(
        NOT (
            delivery_window, current_quantity, minimum_inventory_threshold, minimum_order_quantity
        ) IS NULL
    )
);

CREATE FUNCTION service_center_inventory_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.current_quantity < 0 THEN

                RAISE EXCEPTION
                    'Negative current quantity (%) on TABLE service_center_inventory',
                    NEW.current_quantity;

            WHEN NEW.minimum_inventory_threshold < 0 THEN

                RAISE EXCEPTION
                    'Negative minimum inventory threshold (%) on TABLE service_center_inventory',
                     NEW.minimum_inventory_threshold;

            WHEN NEW.minimum_order_quantity < 1 THEN

                RAISE EXCEPTION
                    'Illicit minimum order quantity (%) on TABLE service_center_inventory',
                    NEW.minimum_order_quantity;

            WHEN NEW.delivery_window IS NOT NULL
                 AND NEW.delivery_window < 0 THEN

                RAISE EXCEPTION
                    'Negative delivery window (%) on TABLE service_center_inventory',
                    NEW.delivery_window;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER service_center_inventory_constraints BEFORE INSERT OR UPDATE ON service_center_inventory
    FOR EACH ROW EXECUTE FUNCTION service_center_inventory_constraints();

--

CREATE TABLE service_history (
    id text,
    license_plate_number text,
    service_type text,
    service_date date,
    customer_id text,
    service_center_id text,
    starting_time time,
    mechanic_name text,
    PRIMARY KEY (id),
    FOREIGN KEY (license_plate_number) REFERENCES cars ON DELETE RESTRICT,
    FOREIGN KEY (service_type) REFERENCES service_types (derived_type) ON DELETE RESTRICT,
    FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE RESTRICT,
    FOREIGN KEY (service_center_id) REFERENCES service_centers (id) ON DELETE RESTRICT,
    CHECK(NOT (service_date, starting_time, mechanic_name) IS NULL)
);

CREATE FUNCTION service_history_constraints() RETURNS trigger AS $$
    #variable_conflict use_column

    BEGIN
        CASE
            WHEN NEW.id !~ 'H\d{4}' THEN

                RAISE EXCEPTION 'Illicit ID (%) on TABLE service_history',
                                NEW.id;

            WHEN NOT EXISTS(
                     SELECT 1
                     FROM employees OLD
                     WHERE OLD.name = NEW.mechanic_name
                 ) THEN

                RAISE EXCEPTION 'Illicit mechanic name (%) on TABLE service_history',
                                NEW.mechanic_name;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER service_history_constraints BEFORE INSERT OR UPDATE ON service_history
    FOR EACH ROW EXECUTE FUNCTION service_history_constraints();

--

CREATE TABLE warranty_history (
    license_plate_number text,
    part_id text,
    service_date date,
    expiration_date date,
    PRIMARY KEY (license_plate_number, part_id, service_date),
    FOREIGN KEY (license_plate_number) REFERENCES cars ON DELETE CASCADE,
    FOREIGN KEY (part_id) REFERENCES parts (id) ON DELETE CASCADE,
    CHECK(NOT (service_date, expiration_date) IS NULL)
);

CREATE FUNCTION warranty_history_constraints() RETURNS trigger AS $$
    #variable_conflict use_column

    BEGIN
        CASE
            WHEN NOT EXISTS(
                     WITH part AS (
                         SELECT warranty
                         FROM parts
                         WHERE parts.id = NEW.part_id
                     ),
                     warranty AS (
                        SELECT warranty AS value,
                               '1 mon'::interval * warranty AS months
                        FROM part
                     )

                     SELECT 1
                     FROM service_history OLD
                     WHERE
                         (SELECT value FROM warranty) IS NOT NULL
                         AND OLD.service_date = NEW.service_date
                         AND OLD.service_date + (SELECT months FROM warranty) = NEW.expiration_date
                 ) THEN

                RAISE EXCEPTION 'Illicit warranty (% % %) on TABLE warranty_history',
                                NEW.license_plate_number,
                                NEW.part_id,
                                NEW.service_date;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER warranty_history_constraints BEFORE INSERT OR UPDATE ON warranty_history
    FOR EACH ROW EXECUTE FUNCTION warranty_history_constraints();

--

CREATE TABLE order_status (
    name text,
    PRIMARY KEY (name)
);

--

CREATE TABLE orders (
    id text,
    order_placement_date date,
    expeted_delivery_date date,
    actual_delivery_date date,
    maker text,
    part text,
    quantity integer,
    source_id text,
    destination_id text,
    order_status text,
    PRIMARY KEY (id),
    FOREIGN KEY (maker) REFERENCES makers (name) ON DELETE RESTRICT,
    FOREIGN KEY (source_id) REFERENCES inventories (id) ON DELETE RESTRICT,
    FOREIGN KEY (destination_id) REFERENCES inventories (id) ON DELETE RESTRICT,
    FOREIGN KEY (order_status) REFERENCES order_status (name) ON DELETE RESTRICT,
    CHECK(NOT (order_placement_date, expeted_delivery_date, part, quantity) IS NULL)
);

CREATE FUNCTION order_constraints() RETURNS trigger AS $$
    #variable_conflict use_column

    BEGIN
        CASE
            WHEN NEW.id !~ 'O\d{4}' THEN
                RAISE EXCEPTION 'Illicit ID (%) on TABLE orders', NEW.id;

            WHEN NOT EXISTS(
                     SELECT 1
                     FROM parts OLD
                     WHERE OLD.maker = NEW.maker
                       AND OLD.name = NEW.part
                 ) THEN
                
                RAISE EXCEPTION 'Illicit part (% %) on TABLE orders', NEW.maker, NEW.part;

            WHEN NEW.quantity < 1 THEN
                RAISE EXCEPTION 'Illicit quantity (%) on TABLE orders', NEW.quantity;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER order_constraints BEFORE INSERT OR UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION order_constraints();

--

CREATE TABLE notifications (
    id text,
    starting_date date,
    service_center_id text,
    order_message text,
    PRIMARY KEY (id),
    FOREIGN KEY (service_center_id) REFERENCES service_centers (id) ON DELETE RESTRICT,
    CHECK(NOT (starting_date, order_message) IS NULL)
);

CREATE FUNCTION notification_constraints() RETURNS trigger AS $$
    BEGIN
        CASE
            WHEN NEW.id !~ 'N\d{4}' THEN
                RAISE EXCEPTION 'Illicit ID (%) on TABLE notifications', NEW.id;

            ELSE
                -- This case raises no exception.
        END CASE;

        RETURN NEW;
    END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER notification_constraints BEFORE INSERT OR UPDATE ON notifications
    FOR EACH ROW EXECUTE FUNCTION notification_constraints();
