------------------------------------------------------------------------------
--
--  Change application objects owner
--
--    Usage:     CALL mySchema.p_dba_change_owner( p_new_owner )
--               To be executed e.g. after deployment or DB restore
--
--       ** Version for Postgres Flex Server v14 **
--
--    Set new owner to the following application code objects in current schema(!):
--      schemas,
--      tables (including partitions)
--      views,
--      routines (functions, procedures)
--      types
--  ** Must be executed with appropriate entitlements, as DB admin or schema owner **
--  ** or grants must be inherited through 'SECURITY DEFINER'  **
--
--  Does not change any internal or public Postgres objects, only application code
--
--
--  https://github.com/Krzysztof-Rogoz/PostgreSQL-samples
--
--  Created: 12-Jan-2024
--  Author: Krzysztof Rogoz
--  https://www.linkedin.com/in/krzysztof-rogoz-19b6781/
------------------------------------------------------------------------------


CREATE OR REPLACE PROCEDURE <mySchema>.p_dba_change_owner(p_new_owner TEXT)
LANGUAGE 'plpgsql'
SECURITY DEFINER
AS $code$
  DECLARE
    rec      RECORD;
    v_dummy  INTEGER;
    v_stack    TEXT;
    v_fcesig    TEXT;
  BEGIN
    GET DIAGNOSTICS v_stack = PG_CONTEXT;
    v_fcesig := SUBSTRING(v_stack from 'function (.*?) line');
    RAISE INFO '*** PROCEDURE % STARTED:', v_fcesig::regprocedure::text;
--
-- Take over schemas ownership
EXECUTE 'ALTER SCHEMA <mySchema> OWNER TO "'||p_new_owner||'"';
--
-- Take over types:
    FOR rec IN
      SELECT  DISTINCT 'ALTER TYPE '||n.nspname||'.'||t.typname||' OWNER TO "'  ||p_new_owner||'"' sqlcmd
        FROM  pg_type t
                 LEFT JOIN   pg_catalog.pg_namespace n ON n.oid = t.typnamespace
       WHERE  (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
         AND  NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
         AND     n.nspname NOT IN ('pg_catalog', 'information_schema')
     LOOP
   RAISE INFO '%', rec.sqlcmd;
   EXECUTE rec.sqlcmd;
     END LOOP;
    --
-- Take over tables and views ownership
    FOR rec IN
      SELECT 'ALTER TABLE '||table_schema||'.'||table_name||' OWNER TO "'||p_new_owner||'"' sqlcmd
        FROM information_schema.tables
       WHERE table_schema IN ('mySchema')
         AND table_type IN ('BASE TABLE','VIEW')
     LOOP
   RAISE INFO '%', rec.sqlcmd;
   EXECUTE rec.sqlcmd;
     END LOOP;
--
-- Take over proc and functions ownership
     FOR rec IN
         SELECT DISTINCT 'ALTER ROUTINE '||nspname||'.'||proname||' OWNER TO "'||p_new_owner||'"' sqlcmd
                  FROM pg_proc JOIN pg_namespace n  ON  pronamespace = n.oid
           WHERE  nspname IN ('mySchema')
     AND (proname LIKE 'f\_%' OR proname LIKE 'p\_%')    -- NOTE: this line of code refers naming convention: p_procedure(), f_function()....
AND POSITION(proname in v_fcesig::regprocedure::text) = 0
         LOOP
   RAISE INFO '%', rec.sqlcmd;
       EXECUTE rec.sqlcmd;
         END LOOP;
    --
RAISE INFO '*** PROCEDURE % SUCCESSFULLY ENDED, new owner: %...', v_fcesig::regprocedure::text, p_new_owner;
END $code$;