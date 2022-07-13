create or replace package body test_lineage_util is

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
      l_actual   t_col_type;
      l_expected t_col_type;
   begin
      -- non-recursive
      l_actual   := lineage_util.get_dep_cols_from_query(
                       in_parse_user => user,
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
      ut.expect(l_actual.count).to_equal(2);
      l_expected := t_col_type(
                       col_type(user, 'TABLE', 'EMP', 'COMM'),
                       col_type(user, 'TABLE', 'EMP', 'SAL')
                    );
      ut.expect(sys.anydata.convertcollection(l_actual)).to_equal(sys.anydata.convertcollection(l_expected)).unordered;
      -- recursive
      l_actual   := lineage_util.get_dep_cols_from_query(
                       in_parse_user => user,
                       in_query      => q'[
                          select dept_no, dept_name, salary
                            from source_view
                       ]',
                       in_column_pos => 3,
                       in_recursive  => 1
                    );
      ut.expect(l_actual.count).to_equal(3);
      l_expected := t_col_type(
                       col_type(user, 'TABLE', 'EMP', 'COMM'),
                       col_type(user, 'TABLE', 'EMP', 'SAL'),
                       col_type(user, 'VIEW', 'SOURCE_VIEW', 'SALARY')
                    );
      ut.expect(sys.anydata.convertcollection(l_actual)).to_equal(sys.anydata.convertcollection(l_expected)).unordered;
   end test_get_dep_cols_from_query;

   --
   -- test_get_dep_cols_from_view
   --
   procedure test_get_dep_cols_from_view is
      l_actual   t_col_type;
      l_expected t_col_type;
   begin
      l_actual   := lineage_util.get_dep_cols_from_view(
                       in_owner       => user,
                       in_object_name => 'SOURCE_VIEW',
                       in_column_name => 'SALARY',
                       in_recursive   => 0
                    );
      ut.expect(l_actual.count).to_equal(2);
      l_expected := t_col_type(
                       col_type(user, 'TABLE', 'EMP', 'COMM'),
                       col_type(user, 'TABLE', 'EMP', 'SAL')
                    );
      ut.expect(sys.anydata.convertcollection(l_actual)).to_equal(sys.anydata.convertcollection(l_expected)).unordered;
   end test_get_dep_cols_from_view;

   --
   -- test_get_dep_cols_from_insert
   --
   procedure test_get_dep_cols_from_insert is
      l_signature varchar2(32 byte); -- NOSONAR: G-2110
      l_actual    t_col_lineage_type;
      l_expected  t_col_lineage_type;
   begin
      select signature -- NOSONAR: G-5060
        into l_signature
        from sys.user_statements -- NOSONAR: avoid public synonym
       where text = 'INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY) SELECT DEPT_NO, DEPT_NAME, SALARY FROM SOURCE_SYN';
      -- non-recursive
      l_actual   := lineage_util.get_dep_cols_from_insert(in_signature => l_signature, in_recursive => 0);
      ut.expect(l_actual.count).to_equal(3);
      l_expected := t_col_lineage_type(
                       col_lineage_type(user, 'VIEW', 'SOURCE_VIEW', 'DEPT_NAME', user, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_lineage_type(user, 'VIEW', 'SOURCE_VIEW', 'DEPT_NO', user, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_lineage_type(user, 'VIEW', 'SOURCE_VIEW', 'SALARY', user, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(sys.anydata.convertcollection(l_actual)).to_equal(sys.anydata.convertcollection(l_expected))
      .join_by('FROM_COLUMN_NAME');
      -- recursive
      l_actual   := lineage_util.get_dep_cols_from_insert(in_signature => l_signature, in_recursive => 1);
      ut.expect(l_actual.count).to_equal(7);
      l_expected := t_col_lineage_type(
                       col_lineage_type(user, 'TABLE', 'DEPT', 'DEPTNO', user, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_lineage_type(user, 'TABLE', 'DEPT', 'DNAME', user, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_lineage_type(user, 'TABLE', 'EMP', 'COMM', user, 'TABLE', 'DEPTSAL', 'SALARY'),
                       col_lineage_type(user, 'TABLE', 'EMP', 'SAL', user, 'TABLE', 'DEPTSAL', 'SALARY'),
                       col_lineage_type(user, 'VIEW', 'SOURCE_VIEW', 'DEPT_NAME', user, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_lineage_type(user, 'VIEW', 'SOURCE_VIEW', 'DEPT_NO', user, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_lineage_type(user, 'VIEW', 'SOURCE_VIEW', 'SALARY', user, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(sys.anydata.convertcollection(l_actual)).to_equal(sys.anydata.convertcollection(l_expected)).unordered;
   end test_get_dep_cols_from_insert;
   
   --
   -- test_get_target_cols_from_insert
   --
   procedure test_get_target_cols_from_insert is
      l_signature varchar2(32 byte); -- NOSONAR: G-2110
      l_actual    t_col_type;
      l_expected  t_col_type;
   begin
      -- explicit target columns
      select signature -- NOSONAR: G-5060
        into l_signature
        from sys.user_statements -- NOSONAR: avoid public synonym
       where text = 'INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY) SELECT DEPT_NO, DEPT_NAME, SALARY FROM SOURCE_SYN';
      l_actual   := lineage_util.get_target_cols_from_insert(l_signature);
      ut.expect(l_actual.count).to_equal(3);
      l_expected := t_col_type(
                       col_type(user, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_type(user, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_type(user, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(sys.anydata.convertcollection(l_actual)).to_equal(sys.anydata.convertcollection(l_expected)).unordered;
      -- implicit target columns
      select signature -- NOSONAR: G-5060
        into l_signature
        from sys.user_statements -- NOSONAR: avoid public synonym
       where text = 'INSERT INTO DEPTSAL SELECT T.* FROM SOURCE_SYN T';
      l_actual   := lineage_util.get_target_cols_from_insert(l_signature);
      ut.expect(l_actual.count).to_equal(3);
      l_expected := t_col_type(
                       col_type(user, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_type(user, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_type(user, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(sys.anydata.convertcollection(l_actual)).to_equal(sys.anydata.convertcollection(l_expected)).unordered;
   end test_get_target_cols_from_insert;

end test_lineage_util;
/
