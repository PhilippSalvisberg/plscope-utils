create or replace package etl as
   procedure load_from_tab;
   procedure load_from_view;
   procedure load_from_syn;
   procedure load_from_syn_wild;
   procedure load_from_syn_log;
   procedure load_multi_table;
   procedure load_from_implicit_cursor;
   procedure load_from_explicit_cursor;
   procedure load_from_dyn_sql;
   function sal_of_dept(in_deptno in dept.deptno%type) return deptsal.salary%type;
   procedure load_from_app_join;
end etl;
/
