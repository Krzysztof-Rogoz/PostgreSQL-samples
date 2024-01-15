------------------------------------------------------------------------------
--
--  Refresh grants
--
--  Usage:    CALL p_dba_refresh_grants()
--            CALL p_dba_refresh_grants('<schema>')
--     To be executed e.g. after deployment, to optimize grants management
--
--  Tested on: Postgres Flex Server v14 in Azure
--
--  ** Procedure logic: **
--  Full setup of Db-objects grants: tables, views, procedures, functions, types
--    - starts from revoking all existing access rights, especially from PUBLIC
--    - set default privileges for schema
--    - selective set of proper privileges (data read-only, data read-write, schema owner in some cases)
--      for selected schema based on naming convention (prefixes: RO for views v_ )
--
--  Access is granted to 2 roles that must exist: db_readonly and db_readwrite
--  Tables owner can be different in each environment, owners name is extracted
--  from existing objects and used in dynamic sql.
--
--
--  https://github.com/Krzysztof-Rogoz/PostgreSQL-samples
--
--  Created: 12-Jan-2024
--  Author: Krzysztof Rogoz
--  https://www.linkedin.com/in/krzysztof-rogoz-19b6781/
------------------------------------------------------------------------------

--CREATE ROLE db_readonly WITH
--	NOLOGIN	NOSUPERUSER	NOCREATEDB	NOCREATEROLE INHERIT NOREPLICATION
--	CONNECTION LIMIT -1;

--CREATE ROLE db_readwrite WITH
--	NOLOGIN	NOSUPERUSER	NOCREATEDB	NOCREATEROLE INHERIT NOREPLICATION
--	CONNECTION LIMIT -1;

CREATE OR REPLACE PROCEDURE p_dba_refresh_grants(p_schema TEXT DEFAULT 'mySchema')
  LANGUAGE 'plpgsql'
  SECURITY DEFINER
 AS $code$
  DECLARE
    rec       RECORD;
    v_owner   pg_tables.tableowner%TYPE;
    v_dummy   INTEGER;
    v_stack   TEXT;
    v_fcesig  TEXT;
  BEGIN
    PERFORM set_config('search_path', p_schema||', public', false);
    -- Get the name of current procedure to be later displayed in msg:
    GET DIAGNOSTICS v_stack = PG_CONTEXT;
    v_fcesig := SUBSTRING(v_stack from 'function (.*?) line');
    RAISE INFO '*** PROCEDURE % STARTED', REPLACE(v_fcesig::regprocedure::text,'text',''''||p_schema||'''');
    --
    --
    -- Trick: in various env DB owner name may be different
    -- Find (confirm) PG role being current owner of all objects
    SELECT tableowner, count(*)
       INTO v_owner, v_dummy
       FROM pg_tables
      WHERE schemaname = p_schema
        AND tablename NOT LIKE 'part_%'  -- exclude partitions (all names must start from part_ !! )
      GROUP BY tableowner
      ORDER BY 2 DESC
      LIMIT 1;
    --
    --
    -- *** Setup default values for schema, typically applicable only  ***
    -- *** at the first run, restoring access if changed in meantime   ***
    --
    -- just on schema, to create objects, applicable
    EXECUTE 'REVOKE CREATE ON SCHEMA ' || p_schema || ' FROM db_readonly';
    EXECUTE 'GRANT USAGE ON SCHEMA ' || p_schema || ' TO db_readonly';
    EXECUTE 'REVOKE CREATE ON SCHEMA ' || p_schema || ' FROM db_readwrite';
    EXECUTE 'GRANT USAGE ON SCHEMA ' || p_schema || ' TO db_readwrite';
    --
    --  Default privileges - for objects created in future, not applicable to existing ones:
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA ' || p_schema || ' REVOKE ALL ON TABLES FROM PUBLIC';  -- includes views
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA ' || p_schema || ' REVOKE ALL ON ROUTINES FROM PUBLIC';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA ' || p_schema || ' REVOKE ALL ON TYPES FROM PUBLIC';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA ' || p_schema || ' REVOKE ALL ON FUNCTIONS FROM PUBLIC';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA ' || p_schema || ' REVOKE ALL ON TABLES FROM db_readwrite';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA ' || p_schema || ' GRANT ALL ON TYPES TO "'||v_owner||'" WITH GRANT OPTION';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA ' || p_schema || ' GRANT ALL ON TABLES TO "'||v_owner||'" WITH GRANT OPTION';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA ' || p_schema || ' GRANT EXECUTE ON ROUTINES TO "'||v_owner||'" WITH GRANT OPTION';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA ' || p_schema || ' GRANT ALL ON TYPES TO db_readwrite WITH GRANT OPTION';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA ' || p_schema || ' GRANT EXECUTE ON ROUTINES TO db_readwrite WITH GRANT OPTION';
    --
    -- Cleanup: revoke all existing grants from tables and views
    FOR rec IN
      SELECT  DISTINCT 'REVOKE  ALL ON TABLE '||acl.relname||' FROM "'||g.rolname||'"' AS sqlcmd
        FROM (SELECT relname, (aclexplode(relacl)).grantee FROM pg_class ) acl
          JOIN pg_roles g ON g.oid = acl.grantee
          JOIN information_schema.tables t ON t.table_name = acl.relname
       WHERE t.table_schema = p_schema
         AND table_type in ('BASE TABLE','VIEW', 'TYPE')
    LOOP
      EXECUTE rec.sqlcmd;
    END LOOP;
    RAISE INFO '---*** GRANTS REVOKED IN SCHEMA % ***--- ', p_schema;
    --
    -- Restore Ins/Upd/Del/Sel access to objects owner, works for both: TABLES and VIEWS
    EXECUTE 'GRANT ALL ON ALL TABLES IN SCHEMA '||p_schema||' TO "'||v_owner||'"';
    RAISE INFO '---*** GRANTS RESTORED TO OWNER IN SCHEMA % ***--- ', p_schema;
    --
    --
    -- Grant read-only access to views and "staging" tables providing processed data (DWH standard)
    -- table naming convention specific for the application, needs to be adjusted to local conditions...
    FOR rec IN
      SELECT 'GRANT SELECT ON TABLE '||table_schema||'.'||table_name||' TO db_readonly' AS sqlcmd
        FROM information_schema.tables t
       WHERE table_schema = p_schema
         AND table_type in ('BASE TABLE','VIEW')
         AND ( table_name LIKE 'v\_%' OR table_name LIKE 'stg\_%' OR table_name LIKE 'myAnyPrefix\_%' )
    LOOP
      EXECUTE rec.sqlcmd;
    END LOOP;
    RAISE INFO '---*** RO granted to all views and tables...  ***--- ';
    --
    --
    -- table naming convention specific for schema RIRA!!
    FOR rec IN
      SELECT 'GRANT ALL ON TABLE '||table_schema||'.'||table_name||' TO db_readwrite' AS sqlcmd
        FROM information_schema.tables t
       WHERE table_schema = p_schema
         AND table_type in ('BASE TABLE')
         AND ( table_name LIKE 'imp\_%' OR table_name LIKE 'log\_%' OR table_name LIKE 'myOtherPrefix\_%' )
    LOOP
      EXECUTE rec.sqlcmd;
    END LOOP;
    RAISE INFO '---*** RW granted to IMP_, LOG_, other...  tables ***--- ';
     --
     --  Routines (Procedures and Functions) are maintained through another PG views
     --  Revoke existing grants from all functions and procedures in schema RIRA, new set will be assigned
    FOR rec IN
       SELECT 'REVOKE EXECUTE ON ROUTINE '||nspname||'.'||acl.proname||' FROM "'||g.rolname||'"' AS sqlcmd
         FROM (SELECT nspname, proname, (aclexplode(proacl)).grantee
                 FROM pg_proc JOIN pg_namespace n  ON  pronamespace = n.oid
                WHERE  nspname = p_schema
                  AND POSITION(proname in v_fcesig::regprocedure::text) = 0) acl
              JOIN pg_roles g ON g.oid = acl.grantee
    LOOP
      EXECUTE rec.sqlcmd;
    END LOOP;
    RAISE INFO '---*** EXEC on f_fun, and p_procs REVOKED ***--- ';
    --
    --
    FOR rec IN
      SELECT 'GRANT EXECUTE ON ROUTINE '||p_schema||'.'||proname||' TO db_readwrite,"'||v_owner||'"' AS sqlcmd
        FROM pg_proc JOIN pg_namespace n  ON  pronamespace = n.oid
       WHERE nspname = p_schema
         AND (proname LIKE 'f\_%' OR proname LIKE 'p\_%')
    LOOP
      BEGIN
        EXECUTE rec.sqlcmd;
      EXCEPTION
        WHEN others THEN
          RAISE INFO 'Exception thrown by: %', rec.sqlcmd;
      END;
    END LOOP;
    RAISE INFO '---*** EXEC granted to f_fun, and p_procs ***--- ';
    --
    --
    --
    RAISE INFO '*** PROCEDURE % SUCCESSFULLY COMPLETED', REPLACE(v_fcesig::regprocedure::text,'text',''''||p_schema||'''');
    --
END $code$;
