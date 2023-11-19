------------------------------------------------------------------------------
--
--  The Magic of Digits
--
--  https://github.com/Krzysztof-Rogoz/PostgreSQL-samples
--
--  Created: 19-Nov-2023
--  Author: Krzysztof Rogoz
--  https://www.linkedin.com/in/krzysztof-rogoz-19b6781/
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.f_solution(in_numbers_list SMALLINT[])
RETURNS smallint AS $$
  DECLARE
    -- for phase 1
    one_number  SMALLINT;
	processed_number TEXT := '{}';
	uniq_digits TEXT;
	up_to_2_digits_in_prev_item_yn BOOLEAN := false;
	arr_unified TEXT[] := '{}';   -- format: 2 digits per number from list, XX as separator for numbers containing >2 digits, 1 digit repeated twice...
	str_unified TEXT := '';
	-- for phase 2
	cnt_current_item_in_seq SMALLINT := 0;  -- count items
	cnt_max_item_in_seq SMALLINT := -1;
  BEGIN
    RAISE DEBUG 'Debug enabled, input arguments: ==>> % <<==', in_numbers_list;
	--
	-- Phase 1: move transformed only relevant items + separators
    FOREACH one_number IN ARRAY in_numbers_list LOOP
	  processed_number :=  CAST(one_number AS TEXT);  
	  processed_number := '{'||trim(regexp_replace(processed_number,'(.)','\1,','g'),',')||'}';  -- separate digits with commas to facil. conversion
	  RAISE DEBUG '  >> %', processed_number;
	  SELECT ARRAY_TO_STRING( ARRAY( SELECT DISTINCT UNNEST( processed_number::text[] ) order by 1), '' ) INTO uniq_digits;
	  IF LENGTH(uniq_digits)=2 THEN
        arr_unified := array_append(arr_unified,uniq_digits::TEXT);
		up_to_2_digits_in_prev_item_yn := true;
      ELSIF LENGTH(uniq_digits)=1 THEN
        arr_unified := array_append(arr_unified,uniq_digits||uniq_digits::TEXT);  -- repeat single digit for unified size: 2 digit ber item
		up_to_2_digits_in_prev_item_yn := true;		
	  ELSIF up_to_2_digits_in_prev_item_yn THEN --prev item was valid, so one separator must be applied
	    arr_unified := array_append(arr_unified,'XX');   -- separsator instead of valid item
		up_to_2_digits_in_prev_item_yn := false;
	  END IF;
    END LOOP;
	RAISE DEBUG 'Array after step 1  ===>>>:  %', arr_unified;
	str_unified := ARRAY_TO_STRING(arr_unified,'');
	RAISE DEBUG 'Array after step 1  ===>>>:  %', str_unified;
	--
	--  Exit immediate in case of  zero valid items
	IF LENGTH(REPLACE(str_unified,'X',''))=0 THEN
	  RETURN 0;
	END IF;
	--
	-- Phase 2: Iterate across digit pairs: 01, 02,..09, 12, 13, ..19, 23, 24... (do not repeat reversed: 10,20 etc) 
	--          Scan processed (unified) array (fixed item length: 22 characters) and find the longest sequence per each pair
	-- 
	FOR i IN 0..8 LOOP
      RAISE DEBUG ' ########i=%', i;
      FOR j IN i+1..9 LOOP
	    cnt_current_item_in_seq := 0;
        FOR pos_i IN 1..LENGTH(str_unified) BY 2 LOOP
	      IF SUBSTRING(str_unified,pos_i,1) IN (i::CHAR,j::CHAR) AND SUBSTRING(str_unified,pos_i+1,1) IN (i::CHAR,j::CHAR)
		  THEN   
			cnt_current_item_in_seq = cnt_current_item_in_seq + 1; 
		    IF cnt_current_item_in_seq > cnt_max_item_in_seq THEN 
			  cnt_max_item_in_seq := cnt_current_item_in_seq;
			END IF;	
		    RAISE DEBUG 'Found i=%, j=%, pos_i=%, curr=%, max=%', i, j, pos_i, cnt_current_item_in_seq, cnt_max_item_in_seq;
		  ELSE 
		    RAISE DEBUG 'At least one mis OR separ: i=%, j=%, pos_i=%, curr=%, max=%', i, j, pos_i, cnt_current_item_in_seq, cnt_max_item_in_seq;
		    IF cnt_current_item_in_seq > cnt_max_item_in_seq THEN 
			  cnt_max_item_in_seq := cnt_current_item_in_seq;
			END IF;	
			cnt_current_item_in_seq := 0;
		  END IF;
		END LOOP;
	    IF cnt_current_item_in_seq > cnt_max_item_in_seq THEN 
	      cnt_max_item_in_seq := cnt_current_item_in_seq;
	      cnt_current_item_in_seq := 0;
		  RAISE DEBUG 'Finally: i=%, j=%, curr=%, max=%', i, j, cnt_current_item_in_seq, cnt_max_item_in_seq;
	    END IF;	
      END LOOP;
	END LOOP;
    RETURN cnt_max_item_in_seq;
  END;
$$
LANGUAGE plpgsql;



----- Setup env for automated unit tests ------
-->>CREATE EXTENSION intarray;
DROP TYPE IF EXISTS t_testSet;
CREATE TYPE t_testSet AS (
	input_list       SMALLINT[],
	expected_result  SMALLINT
);
SET client_min_messages = info;   -- change to DEBUG if needed


----- *** Start automated tests *** ------
DO $$
DECLARE
 -- test dataset definition, more tests to be updated if needed:
  myTestSet t_testSet[] := ARRAY[ (ARRAY[23,3333,30,0,1],3)::t_testSet,
								  (ARRAY[23,7,3333,30,0,4,0,0,0,1,8],5)::t_testSet,
								  (ARRAY[123,456],0)::t_testSet,
								  (ARRAY[23,3363,30,0,3,30,37],4)::t_testSet,
								  (ARRAY[123,5,3063,345,30,0,3,3567,30,3,0],3)::t_testSet
								 ];
  myTst  t_testSet;								 
  res    SMALLINT;
BEGIN
  FOREACH myTst IN ARRAY  myTestSet LOOP
    res := pg_temp.f_solution(myTst.input_list);
    IF res = myTst.expected_result THEN  
      RAISE NOTICE 'result: PASS, returned: %, expected: %, input: %', res, myTst.expected_result, myTst.input_list;
    ELSE
      RAISE NOTICE 'Failure, returned: %, expected %, input: %', res, myTst.expected_result, myTst.input_list;
    END IF;
  END LOOP;
END $$;


----- Cleanup env after tests ------
DROP FUNCTION pg_temp.f_solution;
