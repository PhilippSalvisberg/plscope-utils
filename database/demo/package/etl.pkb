CREATE OR REPLACE PACKAGE BODY etl AS
   g_unused_column v$mystat.sid%TYPE;

   PROCEDURE clear_deptsal IS
   BEGIN
      DELETE FROM deptsal;
      DELETE FROM deptsal_err;
      dbms_output.put_line('deptsal an deptsal_err deleted.'); -- use synonym
   END clear_deptsal;
   
   PROCEDURE load_from_tab IS
   BEGIN
      clear_deptsal;
      INSERT INTO deptsal (dept_no, dept_name, salary)
      SELECT /*+ordered */ d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
        FROM dept d
        LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
          ON e.deptno = d.deptno
       GROUP BY d.deptno, d.dname;
      COMMIT;
      sys.dbms_output.put_line('deptsal loaded and commited (from table).');
   END load_from_tab;

   PROCEDURE load_from_view IS
   BEGIN
      clear_deptsal;
      INSERT INTO deptsal (dept_no, dept_name, salary)
      SELECT dept_no, dept_name, salary
        FROM source_view;
      COMMIT;
      sys.dbms_output.put_line('deptsal loaded and commited (from view).');
   END load_from_view;

   PROCEDURE load_from_syn IS
   BEGIN
      clear_deptsal;
      INSERT INTO deptsal (dept_no, dept_name, salary)
      SELECT dept_no, dept_name, salary
        FROM source_syn;
      COMMIT;
      sys.dbms_output.put_line('deptsal loaded and commited (from view via synonym).');
   END load_from_syn;

   PROCEDURE load_from_syn_wild IS
   BEGIN
      clear_deptsal;
      INSERT INTO deptsal  -- no column list
      SELECT t.*           -- all-column wildcard
        FROM source_syn t;
      COMMIT;
      sys.dbms_output.put_line('deptsal loaded and commited' ||
         ' (from view via synonym without explicit column references).');
   END load_from_syn_wild;
   
   PROCEDURE load_from_syn_log IS
   BEGIN
      clear_deptsal;
      INSERT INTO deptsal (dept_no, dept_name, salary)
      SELECT dept_no, dept_name, salary
        FROM source_syn s
      LOG ERRORS INTO deptsal_err REJECT LIMIT 10;
      COMMIT;
      sys.dbms_output.put_line('deptsal loaded and commited (with log errors).');
   END load_from_syn_log;

   PROCEDURE load_multi_table IS
   BEGIN
      clear_deptsal;
      INSERT ALL
         WHEN dept_no <= 100 THEN
            INTO deptsal  -- no column list
         ELSE
            INTO deptsal_err (dept_no, dept_name, salary) 
      SELECT dept_no, dept_name, salary
        FROM source_syn;
      COMMIT;
      sys.dbms_output.put_line('deptsal loaded and commited (from via multi-table-insert).');
   END load_multi_table;

   PROCEDURE load_from_implicit_cursor IS
   BEGIN
      clear_deptsal;
      FOR r_src IN (
         SELECT dept_no, dept_name, salary
           FROM source_syn
      ) LOOP
         INSERT INTO deptsal (dept_no, dept_name, salary)
         VALUES (r_src.dept_no, r_src.dept_name, r_src.salary);
      END LOOP;
      COMMIT;
      sys.dbms_output.put_line('deptsal loaded and commited (from implicit cursor).');
   END load_from_implicit_cursor;

   PROCEDURE load_from_explicit_cursor IS
      CURSOR c_src IS
         SELECT dept_no, dept_name, salary
           FROM source_syn;      
   BEGIN
      clear_deptsal;
      FOR r_src IN c_src LOOP
         INSERT INTO deptsal (dept_no, dept_name, salary)
         VALUES (r_src.dept_no, r_src.dept_name, r_src.salary);
      END LOOP;
      COMMIT;
      sys.dbms_output.put_line('deptsal loaded and commited (from explicit cursor).');
   END load_from_explicit_cursor; 
   
   PROCEDURE load_from_dyn_sql IS
      l_sql VARCHAR2(4000) := q'[
            INSERT INTO deptsal (dept_no, dept_name, salary)
            SELECT /*+ordered */ d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
              FROM dept d
              LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                ON e.deptno = d.deptno
             GROUP BY d.deptno, d.dname
         ]';
   BEGIN
      clear_deptsal;
      EXECUTE IMMEDIATE l_sql;
      COMMIT;
      sys.dbms_output.put_line('deptsal loaded and commited (from dynamic SQL).');
   END load_from_dyn_sql;
   
   FUNCTION sal_of_dept (in_deptno dept.deptno%TYPE) RETURN deptsal.salary%TYPE IS 
      l_salary deptsal.salary%TYPE;
   BEGIN
      SELECT SUM(sal + NVL(comm, 0))
        INTO l_salary
        FROM emp 
       WHERE deptno = in_deptno
         AND hiredate > DATE '1980-01-01';
      RETURN l_salary;
   END sal_of_dept;

   PROCEDURE load_from_app_join IS
   BEGIN
      clear_deptsal;
      INSERT INTO deptsal (dept_no, dept_name, salary)
      SELECT deptno, dname, etl.sal_of_dept(deptno)
        FROM dept;
      COMMIT;
      sys.dbms_output.put_line('deptsal loaded and commited (from application join).');
   END load_from_app_join;

END etl;
/
