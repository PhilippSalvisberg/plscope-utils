create or replace package body test_etl is

   --
   -- check_deptsal_content
   --
   procedure check_deptsal_content is
      c_actual   sys_refcursor;
      c_expected sys_refcursor;
   begin
      open c_actual for select * from deptsal;
      open c_expected for select * from source_view;
      ut.expect(c_actual).to_equal(c_expected).unordered;
   end check_deptsal_content;
   
   --
   -- check_deptsal_err_content
   --
   procedure check_deptsal_err_content is
      l_error_count integer;
   begin
      select count(*)
        into l_error_count
        from deptsal_err;
      ut.expect(l_error_count).to_equal(0);
   end check_deptsal_err_content;
   
   --
   -- test_load_from_tab
   --
   procedure test_load_from_tab is
   begin
      etl.load_from_tab;
      check_deptsal_content;
   end test_load_from_tab;
   
   --
   -- test_load_from_view
   --
   procedure test_load_from_view is
   begin
      etl.load_from_view;
      check_deptsal_content;
   end test_load_from_view;
   
   --
   -- test_load_from_syn
   --
   procedure test_load_from_syn is
   begin
      etl.load_from_syn;
      check_deptsal_content;
   end test_load_from_syn;
   
   --
   -- test_load_from_syn_wild
   --
   procedure test_load_from_syn_wild is
   begin
      etl.load_from_syn_wild;
      check_deptsal_content;
   end test_load_from_syn_wild;
   
   --
   -- test_load_from_syn_log
   --
   procedure test_load_from_syn_log is
   begin
      etl.load_from_syn_log;
      check_deptsal_content;
      check_deptsal_err_content;
   end test_load_from_syn_log;
   
   --
   -- test_load_multi_table
   --
   procedure test_load_multi_table is
   begin
      etl.load_multi_table;
      check_deptsal_content;
      check_deptsal_err_content;
   end test_load_multi_table;
   
   --
   -- test_load_from_implicit_cursor
   --
   procedure test_load_from_implicit_cursor is
   begin
      etl.load_from_implicit_cursor;
      check_deptsal_content;
   end test_load_from_implicit_cursor;
   
   --
   -- test_load_from_explicit_cursor
   --
   procedure test_load_from_explicit_cursor is
   begin
      etl.load_from_explicit_cursor;
      check_deptsal_content;
   end test_load_from_explicit_cursor;
   
   --
   -- test_load_from_dyn_sql
   --
   procedure test_load_from_dyn_sql is
   begin
      etl.load_from_dyn_sql;
      check_deptsal_content;
   end test_load_from_dyn_sql;
   
   --
   -- test_sal_of_dept
   --
   procedure test_sal_of_dept is
      l_actual deptsal.salary%type;
   begin
      l_actual := etl.sal_of_dept(10);
      ut.expect(l_actual).to_equal(8750);
   end test_sal_of_dept;
   
   --
   -- test_load_from_app_join
   --
   procedure test_load_from_app_join is
   begin
      etl.load_from_app_join;
      check_deptsal_content;
   end test_load_from_app_join;

end test_etl;
/
