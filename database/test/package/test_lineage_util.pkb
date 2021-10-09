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
                       user,
                       q'[
                        SELECT /*+ordered */ 
                               d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) AS sal
                          FROM dept d
                          LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                            ON e.deptno = d.deptno
                        GROUP BY d.deptno, d.dname
                     ]',
                       3,
                       0
                    );
      ut.expect(l_actual.count).to_equal(2);
      l_expected := t_col_type(
                       col_type(user, 'TABLE', 'EMP', 'COMM'),
                       col_type(user, 'TABLE', 'EMP', 'SAL')
                    );
      ut.expect(anydata.convertcollection(l_actual)).to_equal(anydata.convertcollection(l_expected)).unordered;
      -- recursive
      l_actual   := lineage_util.get_dep_cols_from_query(
                       user,
                       q'[
                        SELECT dept_no, dept_name, salary
                          FROM source_view
                     ]',
                       3,
                       1
                    );
      ut.expect(l_actual.count).to_equal(3);
      l_expected := t_col_type(
                       col_type(user, 'TABLE', 'EMP', 'COMM'),
                       col_type(user, 'TABLE', 'EMP', 'SAL'),
                       col_type(user, 'VIEW', 'SOURCE_VIEW', 'SALARY')
                    );
      ut.expect(anydata.convertcollection(l_actual)).to_equal(anydata.convertcollection(l_expected)).unordered;
   end test_get_dep_cols_from_query;

   --
   -- test_get_dep_cols_from_view
   --
   procedure test_get_dep_cols_from_view is
      l_actual   t_col_type;
      l_expected t_col_type;
   begin
      l_actual   := lineage_util.get_dep_cols_from_view(
                       user,
                       'SOURCE_VIEW',
                       'SALARY',
                       0
                    );
      ut.expect(l_actual.count).to_equal(2);
      l_expected := t_col_type(
                       col_type(user, 'TABLE', 'EMP', 'COMM'),
                       col_type(user, 'TABLE', 'EMP', 'SAL')
                    );
      ut.expect(anydata.convertcollection(l_actual)).to_equal(anydata.convertcollection(l_expected)).unordered;
   end test_get_dep_cols_from_view;

   --
   -- test_get_dep_cols_from_insert
   --
   procedure test_get_dep_cols_from_insert is
      l_signature varchar2(32 byte);
      l_actual    t_col_lineage_type;
      l_expected  t_col_lineage_type;
   begin
      select signature
        into l_signature
        from user_statements
       where text = 'INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY) SELECT DEPT_NO, DEPT_NAME, SALARY FROM SOURCE_SYN';
      -- non-recursive
      l_actual   := lineage_util.get_dep_cols_from_insert(l_signature, 0);
      ut.expect(l_actual.count).to_equal(3);
      l_expected := t_col_lineage_type(
                       col_lineage_type(user, 'VIEW', 'SOURCE_VIEW', 'DEPT_NAME', user, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_lineage_type(user, 'VIEW', 'SOURCE_VIEW', 'DEPT_NO', user, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_lineage_type(user, 'VIEW', 'SOURCE_VIEW', 'SALARY', user, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(anydata.convertcollection(l_actual)).to_equal(anydata.convertcollection(l_expected))
      .join_by('FROM_COLUMN_NAME');
      -- recursive
      l_actual   := lineage_util.get_dep_cols_from_insert(l_signature, 1);
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
      ut.expect(anydata.convertcollection(l_actual)).to_equal(anydata.convertcollection(l_expected)).unordered;
   end test_get_dep_cols_from_insert;
   
   --
   -- test_get_target_cols_from_insert
   --
   procedure test_get_target_cols_from_insert is
      l_signature varchar2(32 byte);
      l_actual    t_col_type;
      l_expected  t_col_type;
   begin
      -- explicit target columns
      select signature
        into l_signature
        from user_statements
       where text = 'INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY) SELECT DEPT_NO, DEPT_NAME, SALARY FROM SOURCE_SYN';
      l_actual   := lineage_util.get_target_cols_from_insert(l_signature);
      ut.expect(l_actual.count).to_equal(3);
      l_expected := t_col_type(
                       col_type(user, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_type(user, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_type(user, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(anydata.convertcollection(l_actual)).to_equal(anydata.convertcollection(l_expected)).unordered;
      -- implicit target columns
      select signature
        into l_signature
        from user_statements
       where text = 'INSERT INTO DEPTSAL SELECT T.* FROM SOURCE_SYN T';
      l_actual   := lineage_util.get_target_cols_from_insert(l_signature);
      ut.expect(l_actual.count).to_equal(3);
      l_expected := t_col_type(
                       col_type(user, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_type(user, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_type(user, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(anydata.convertcollection(l_actual)).to_equal(anydata.convertcollection(l_expected)).unordered;
   end test_get_target_cols_from_insert;

end test_lineage_util;
/
