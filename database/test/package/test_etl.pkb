CREATE OR REPLACE PACKAGE BODY test_etl IS

   --
   -- check_deptsal_content
   --
   PROCEDURE check_deptsal_content IS
      l_actual   sys_refcursor;
      l_expected sys_refcursor;
   BEGIN
      OPEN l_actual FOR SELECT * FROM deptsal ORDER BY dept_no;
      OPEN l_expected FOR SELECT * FROM source_view ORDER BY dept_no;
      ut.expect(l_actual).to_equal(l_expected);
   END check_deptsal_content;
   
   --
   -- check_deptsal_err_content
   --
   PROCEDURE check_deptsal_err_content IS
      l_error_count INTEGER;
   BEGIN
      SELECT COUNT(*)
        INTO l_error_count
        FROM deptsal_err;
      ut.expect(l_error_count).to_equal(0);
   END check_deptsal_err_content;
   
   --
   -- test_load_from_tab
   --
   PROCEDURE test_load_from_tab IS
   BEGIN
      etl.load_from_tab;
      check_deptsal_content;
   END test_load_from_tab;
   
   --
   -- test_load_from_view
   --
   PROCEDURE test_load_from_view IS
   BEGIN
      etl.load_from_view;
      check_deptsal_content;
   END test_load_from_view;
   
   --
   -- test_load_from_syn
   --
   PROCEDURE test_load_from_syn IS
   BEGIN
      etl.load_from_syn;
      check_deptsal_content;
   END test_load_from_syn;
   
   --
   -- test_load_from_syn_wild
   --
   PROCEDURE test_load_from_syn_wild IS
   BEGIN
      etl.load_from_syn_wild;
      check_deptsal_content;
   END test_load_from_syn_wild;
   
   --
   -- test_load_from_syn_log
   --
   PROCEDURE test_load_from_syn_log IS
   BEGIN
      etl.load_from_syn_log;
      check_deptsal_content;
      check_deptsal_err_content;
   END test_load_from_syn_log;
   
   --
   -- test_load_multi_table
   --
   PROCEDURE test_load_multi_table IS
   BEGIN
      etl.load_multi_table;
      check_deptsal_content;
      check_deptsal_err_content;
   END test_load_multi_table;
   
   --
   -- test_load_from_implicit_cursor
   --
   PROCEDURE test_load_from_implicit_cursor IS
   BEGIN
      etl.load_from_implicit_cursor;
      check_deptsal_content;
   END test_load_from_implicit_cursor;
   
   --
   -- test_load_from_explicit_cursor
   --
   PROCEDURE test_load_from_explicit_cursor IS
   BEGIN
      etl.load_from_explicit_cursor;
      check_deptsal_content;
   END test_load_from_explicit_cursor;
   
   --
   -- test_load_from_dyn_sql
   --
   PROCEDURE test_load_from_dyn_sql IS
   BEGIN
      etl.load_from_dyn_sql;
      check_deptsal_content;
   END test_load_from_dyn_sql;
   
   --
   -- test_sal_of_dept
   --
   PROCEDURE test_sal_of_dept IS
      l_actual NUMBER;
   BEGIN
      l_actual := etl.sal_of_dept(10);
      ut.expect(l_actual).to_equal(8750);
   END test_sal_of_dept;
   
   --
   -- test_load_from_app_join
   --
   PROCEDURE test_load_from_app_join IS
   BEGIN
      etl.load_from_app_join;
      check_deptsal_content;
   END test_load_from_app_join;
   
END test_etl;
/
