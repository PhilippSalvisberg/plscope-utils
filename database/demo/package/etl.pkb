CREATE OR REPLACE PACKAGE BODY etl AS
   g_unused_column v$mystat.sid%TYPE;

   PROCEDURE clear_deptsal IS
   BEGIN
      DELETE FROM deptsal;
      dbms_output.put_line('deptsal deleted.'); -- use synonym
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
      SELECT *             -- all-column wildcard
        FROM source_syn;
       COMMIT;
      sys.dbms_output.put_line('deptsal loaded and commited' ||
         ' (from view via synonym without explicit column references).');
   END load_from_syn_wild;

END etl;
/
