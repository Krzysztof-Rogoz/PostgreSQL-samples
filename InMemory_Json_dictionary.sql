------------------------------------------------------------------------------
--
--  InMemory JSON dictionary
--    Display additional data (e.g. aliases) without joining
--    additional tables, no performance impact
--
--
--  https://github.com/Krzysztof-Rogoz/PostgreSQL-samples
--
--  Created: 27-Nov-2023
--  Author: Krzysztof Rogoz
--  https://www.linkedin.com/in/krzysztof-rogoz-19b6781/
------------------------------------------------------------------------------

--SET search_path TO dev, public;
CREATE OR REPLACE FUNCTION f_get_long_name(in_idx INTEGER)
    RETURNS text
    LANGUAGE plpgsql
  AS $code$
  DECLARE
    myJsonPriorityDict  json := json_object(
	  '{0,1,2,3,4}',
      '{"1. Critical","2. Very important","3. Important but not urgent", "4. Meaningful", "5. Only if time permits"}'
     );
  BEGIN
    RETURN myJsonPriorityDict->>in_idx::CHAR;
  END
  $code$;



------------------------------
--- Test environment (schema: dev)
--------------------------------
SET search_path TO dev, public;

CREATE TABLE IF NOT EXISTS task_bucket (
   id              INTEGER PRIMARY KEY,
   date_created    DATE  DEFAULT current_date,
   task_name       TEXT,
   priority        INTEGER
 );
-- otherwise:
--TRUNCATE TABLE task_bucket;

INSERT INTO task_bucket
 VALUES
   (1, current_date, 'Insignificant layout change',4),
   (2, current_date-3, 'Important performance tuning requested by stakeholders',2),
   (3, current_date, 'Total crash, production system is down!!',0),
   (4, current_date, FORMAT('Logic change required by law, deadline: %s',to_char(current_date+7,'DD-Mon-YY')),1),
   (5, current_date, 'Important logic change useful for stakeholders',2)
;


CREATE OR REPLACE VIEW v_prioritized_descriptive_list_of_tasks
AS
  SELECT  f_get_long_name(priority), date_created, task_name
    FROM task_bucket
   ORDER BY priority, date_created;

-- SELECT * FROM v_prioritized_descriptive_list_of_tasks;