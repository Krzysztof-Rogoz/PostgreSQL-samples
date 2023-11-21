------------------------------------------------------------------------------
--
--  Virtual Months Generator
--
--  Returns: ARRAY of strings YYYY-MM
--
--  Returns N sequential months (6 by default) - in ascending order
--  the first returned is the month passed as input arg. (current month by default)
--  This is a pipeline function,
--   it can be easily modified to return results as comma separated list
--   or records containing DATE, representing the first day of month
--
--  https://github.com/Krzysztof-Rogoz/PostgreSQL-samples
--
--  Created: 21-Nov-2023
--  Author: Krzysztof Rogoz
--  https://www.linkedin.com/in/krzysztof-rogoz-19b6781/
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION f_virtual_months_gener(
  in_start_date DATE DEFAULT CURRENT_DATE,
  in_num_of_months SMALLINT DEFAULT 6
 )
  RETURNS SETOF CHAR(7)
  LANGUAGE plpgsql
AS $code$
  DECLARE
    --ret_string  CHAR(7) := '';
  BEGIN
    FOR i IN 0..in_num_of_months LOOP
      RETURN NEXT EXTRACT(YEAR FROM in_start_date + interval '1 month' * i)::TEXT ||
	               '-' || LPAD(EXTRACT(MONTH FROM in_start_date + interval '1 month' * i)::TEXT, 2, '0');
    END LOOP;
    --
    RETURN;
    -----
END $code$;