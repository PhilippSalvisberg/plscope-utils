create or replace package body test_lineage_util is

   co_plsql_unit_owner constant user_users.username%type := $$PLSQL_UNIT_OWNER;

   --
   -- test_set_get_recursive
   --
   procedure test_set_get_recursive is
   begin
      -- true
      lineage_util.set_recursive(1);
      ut.expect(1).to_equal(lineage_util.get_recursive);
      -- false
      lineage_util.set_recursive(0);
      ut.expect(0).to_equal(lineage_util.get_recursive);
   end test_set_get_recursive;

   --
   -- test_get_dep_cols_from_query
   --
   procedure test_get_dep_cols_from_query is
      t_actual   t_col_type;
      t_expected t_col_type;
   begin
      -- non-recursive
      t_actual   := lineage_util.get_dep_cols_from_query(
                       in_parse_user => co_plsql_unit_owner,
                       in_query      => q'[
                          select /*+ordered */
                                 d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal
                            from dept d
                            left join (select * from emp where hiredate > date '1980-01-01') e
                              on e.deptno = d.deptno
                           group by d.deptno, d.dname
                       ]',
                       in_column_pos => 3,
                       in_recursive  => 0
                    );
      ut.expect(t_actual.count).to_equal(2);
      t_expected := t_col_type(
                       col_type(co_plsql_unit_owner, 'TABLE', 'EMP', 'COMM'),
                       col_type(co_plsql_unit_owner, 'TABLE', 'EMP', 'SAL')
                    );
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
      -- recursive
      t_actual   := lineage_util.get_dep_cols_from_query(
                       in_parse_user => co_plsql_unit_owner,
                       in_query      => q'[
                          select dept_no, dept_name, salary
                            from source_view
                       ]',
                       in_column_pos => 3,
                       in_recursive  => 1
                    );
      ut.expect(t_actual.count).to_equal(3);
      t_expected := t_col_type(
                       col_type(co_plsql_unit_owner, 'TABLE', 'EMP', 'COMM'),
                       col_type(co_plsql_unit_owner, 'TABLE', 'EMP', 'SAL'),
                       col_type(co_plsql_unit_owner, 'VIEW', 'SOURCE_VIEW', 'SALARY')
                    );
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
   end test_get_dep_cols_from_query;

   --
   -- test_get_dep_cols_from_view
   --
   procedure test_get_dep_cols_from_view is
      t_actual   t_col_type;
      t_expected t_col_type;
   begin
      t_actual   := lineage_util.get_dep_cols_from_view(
                       in_owner       => co_plsql_unit_owner,
                       in_object_name => 'SOURCE_VIEW',
                       in_column_name => 'SALARY',
                       in_recursive   => 0
                    );
      ut.expect(t_actual.count).to_equal(2);
      t_expected := t_col_type(
                       col_type(co_plsql_unit_owner, 'TABLE', 'EMP', 'COMM'),
                       col_type(co_plsql_unit_owner, 'TABLE', 'EMP', 'SAL')
                    );
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
   end test_get_dep_cols_from_view;

   --
   -- test_get_dep_cols_from_insert
   --
   procedure test_get_dep_cols_from_insert is
      l_signature varchar2(32 byte); -- NOSONAR: G-2110
      t_actual    t_col_lineage_type;
      t_expected  t_col_lineage_type;
   begin
      select signature -- NOSONAR: G-5060
        into l_signature
        from sys.all_statements -- NOSONAR: avoid public synonym
       where owner = co_plsql_unit_owner
         and object_name = 'ETL'
         and text = 'INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY) SELECT DEPT_NO, DEPT_NAME, SALARY FROM SOURCE_SYN';
      -- non-recursive
      t_actual   := lineage_util.get_dep_cols_from_insert(in_signature => l_signature, in_recursive => 0);
      ut.expect(t_actual.count).to_equal(3);
      t_expected := t_col_lineage_type(
                       col_lineage_type(co_plsql_unit_owner, 'VIEW', 'SOURCE_VIEW', 'DEPT_NAME', co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_lineage_type(co_plsql_unit_owner, 'VIEW', 'SOURCE_VIEW', 'DEPT_NO', co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_lineage_type(co_plsql_unit_owner, 'VIEW', 'SOURCE_VIEW', 'SALARY', co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected))
      .join_by('FROM_COLUMN_NAME');
      -- recursive
      t_actual   := lineage_util.get_dep_cols_from_insert(in_signature => l_signature, in_recursive => 1);
      ut.expect(t_actual.count).to_equal(7);
      t_expected := t_col_lineage_type(
                       col_lineage_type(co_plsql_unit_owner, 'TABLE', 'DEPT', 'DEPTNO', co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_lineage_type(co_plsql_unit_owner, 'TABLE', 'DEPT', 'DNAME', co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_lineage_type(co_plsql_unit_owner, 'TABLE', 'EMP', 'COMM', co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'SALARY'),
                       col_lineage_type(co_plsql_unit_owner, 'TABLE', 'EMP', 'SAL', co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'SALARY'),
                       col_lineage_type(co_plsql_unit_owner, 'VIEW', 'SOURCE_VIEW', 'DEPT_NAME', co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_lineage_type(co_plsql_unit_owner, 'VIEW', 'SOURCE_VIEW', 'DEPT_NO', co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_lineage_type(co_plsql_unit_owner, 'VIEW', 'SOURCE_VIEW', 'SALARY', co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
   end test_get_dep_cols_from_insert;
   
   --
   -- test_get_target_cols_from_insert
   --
   procedure test_get_target_cols_from_insert is
      l_signature varchar2(32 byte); -- NOSONAR: G-2110
      t_actual    t_col_type;
      t_expected  t_col_type;
   begin
      -- explicit target columns
      select signature -- NOSONAR: G-5060
        into l_signature
        from sys.all_statements -- NOSONAR: avoid public synonym
       where owner = co_plsql_unit_owner
         and object_name = 'ETL'
         and text = 'INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY) SELECT DEPT_NO, DEPT_NAME, SALARY FROM SOURCE_SYN';
      t_actual   := lineage_util.get_target_cols_from_insert(l_signature);
      ut.expect(t_actual.count).to_equal(3);
      t_expected := t_col_type(
                       col_type(co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_type(co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_type(co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
      -- implicit target columns
      select signature -- NOSONAR: G-5060
        into l_signature
        from sys.all_statements -- NOSONAR: avoid public synonym
       where owner = co_plsql_unit_owner
         and object_name = 'ETL'
         and text = 'INSERT INTO DEPTSAL SELECT T.* FROM SOURCE_SYN T';
      t_actual   := lineage_util.get_target_cols_from_insert(l_signature);
      ut.expect(t_actual.count).to_equal(3);
      t_expected := t_col_type(
                       col_type(co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_type(co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_type(co_plsql_unit_owner, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
   end test_get_target_cols_from_insert;

end test_lineage_util;
/
