create or replace package body etl as
   g_unused_column sys.v_$mystat.sid%type;

   procedure clear_deptsal is
   begin
      delete from deptsal;
      delete from deptsal_err;
      sys.dbms_output.put_line('deptsal an deptsal_err deleted.'); -- use synonym
   end clear_deptsal;

   procedure load_from_tab is
   begin
      clear_deptsal;
      insert into deptsal (dept_no, dept_name, salary)
      select /*+ordered */ d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal
        from dept d
        left join (select * from emp where hiredate > date '1980-01-01') e
          on e.deptno = d.deptno
       group by d.deptno, d.dname;
      commit;
      sys.dbms_output.put_line('deptsal loaded and commited (from table).');
   end load_from_tab;

   procedure load_from_view is
   begin
      clear_deptsal;
      insert into deptsal (dept_no, dept_name, salary)
      select dept_no, dept_name, salary
        from source_view;
      commit;
      sys.dbms_output.put_line('deptsal loaded and commited (from view).');
   end load_from_view;

   procedure load_from_syn is
   begin
      clear_deptsal;
      insert into deptsal (dept_no, dept_name, salary)
      select dept_no, dept_name, salary
        from source_syn;
      commit;
      sys.dbms_output.put_line('deptsal loaded and commited (from view via synonym).');
   end load_from_syn;

   procedure load_from_syn_wild is
   begin
      clear_deptsal;
      insert into deptsal  -- no column list NOSONAR G-3110
      select t.*           -- all-column wildcard
        from source_syn t;
      commit;
      sys.dbms_output.put_line('deptsal loaded and commited' ||
         ' (from view via synonym without explicit column references).');
   end load_from_syn_wild;

   procedure load_from_syn_log is
   begin
      clear_deptsal;
      insert into deptsal (dept_no, dept_name, salary)
      select dept_no, dept_name, salary
        from source_syn s
         log errors into deptsal_err reject limit 10;
      commit;
      sys.dbms_output.put_line('deptsal loaded and commited (with log errors).');
   end load_from_syn_log;

   procedure load_multi_table is
   begin
      clear_deptsal;
      insert all
         when dept_no <= 100 then
            into deptsal  -- no column list NOSONAR G-3110
         else
            into deptsal_err (dept_no, dept_name, salary)
      select dept_no, dept_name, salary
        from source_syn;
      commit;
      sys.dbms_output.put_line('deptsal loaded and commited (from via multi-table-insert).');
   end load_multi_table;

   procedure load_from_implicit_cursor is
   begin
      clear_deptsal;
      <<deptsal>>
      for r_src in (
         select dept_no, dept_name, salary
           from source_syn
      )
      loop
         insert into deptsal (dept_no, dept_name, salary)
         values (r_src.dept_no, r_src.dept_name, r_src.salary);
      end loop deptsal;
      commit;
      sys.dbms_output.put_line('deptsal loaded and commited (from implicit cursor).');
   end load_from_implicit_cursor;

   procedure load_from_explicit_cursor is
      cursor c_src is
         select dept_no, dept_name, salary
           from source_syn;
   begin
      clear_deptsal;
      <<deptsal>>
      for r_src in c_src
      loop
         insert into deptsal (dept_no, dept_name, salary)
         values (r_src.dept_no, r_src.dept_name, r_src.salary);
      end loop deptsal;
      commit;
      sys.dbms_output.put_line('deptsal loaded and commited (from explicit cursor).');
   end load_from_explicit_cursor;

   procedure load_from_dyn_sql is
      l_sql clob := q'[
            INSERT INTO deptsal (dept_no, dept_name, salary)
            SELECT /*+ordered */ d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
              FROM dept d
              LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                ON e.deptno = d.deptno
             GROUP BY d.deptno, d.dname
         ]';
   begin
      clear_deptsal;
      execute immediate l_sql;
      commit;
      sys.dbms_output.put_line('deptsal loaded and commited (from dynamic SQL).');
   end load_from_dyn_sql;

   function sal_of_dept(in_deptno in dept.deptno%type) return deptsal.salary%type is
      l_salary deptsal.salary%type;
   begin
      select sum(sal + nvl(comm, 0))
        into l_salary
        from emp
       where deptno = in_deptno
         and hiredate > date '1980-01-01';
      return l_salary;
   end sal_of_dept;

   procedure load_from_app_join is
   begin
      clear_deptsal;
      insert into deptsal (dept_no, dept_name, salary)
      select deptno, dname, etl.sal_of_dept(in_deptno => deptno)
        from dept;
      commit;
      sys.dbms_output.put_line('deptsal loaded and commited (from application join).');
   end load_from_app_join;

end etl;
/
