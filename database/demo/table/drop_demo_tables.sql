DECLARE
   PROCEDURE drop_if_exists(in_table_name IN VARCHAR2) IS
      l_found INTEGER;
      l_sql   VARCHAR2(4000);
   BEGIN
      SELECT COUNT(*)
        INTO l_found
        FROM user_tables
       WHERE table_name = UPPER(in_table_name);
      IF l_found > 0 THEN
         l_sql := 'DROP TABLE ' || in_table_name || ' PURGE';
         sys.dbms_output.put_line('executing: ' || l_sql);
         EXECUTE IMMEDIATE l_sql;
         sys.dbms_output.put_line('table ' || in_table_name || ' dropped.');
      END IF;
   END drop_if_exists;
BEGIN
   drop_if_exists('emp');
   drop_if_exists('dept');
   drop_if_exists('deptsal');
   drop_if_exists('deptsal_err');
END;
/
