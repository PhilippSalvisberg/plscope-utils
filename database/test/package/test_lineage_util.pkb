CREATE OR REPLACE PACKAGE BODY test_lineage_util IS

   --
   -- test_set_get_recursive
   --
   PROCEDURE test_set_get_recursive IS
   BEGIN
      -- true
      lineage_util.set_recursive(1);
      ut.expect(1).to_equal(lineage_util.get_recursive);
      -- false
      lineage_util.set_recursive(0);
      ut.expect(0).to_equal(lineage_util.get_recursive);      
   END test_set_get_recursive;

   --
   -- test_get_dep_cols_from_query
   --
   PROCEDURE test_get_dep_cols_from_query IS
      l_actual   t_col_type;
      l_expected t_col_type;
   BEGIN
      -- non-recursive
      l_actual := lineage_util.get_dep_cols_from_query(
                     USER,
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
                       col_type(USER, 'TABLE', 'EMP', 'COMM'),
                       col_type(USER, 'TABLE', 'EMP', 'SAL')
                    );
      ut.expect(anydata.convertCollection(l_actual))
         .to_equal(anydata.convertCollection(l_expected));
      -- recursive
      l_actual := lineage_util.get_dep_cols_from_query(
                     USER,
                     q'[
                        SELECT dept_no, dept_name, salary
                          FROM source_view
                     ]',
                     3,
                     1
                  );
      ut.expect(l_actual.count).to_equal(3);
      l_expected := t_col_type(
                       col_type(USER, 'TABLE', 'EMP', 'COMM'),
                       col_type(USER, 'TABLE', 'EMP', 'SAL'),
                       col_type(USER, 'VIEW', 'SOURCE_VIEW', 'SALARY')
                    );
      ut.expect(anydata.convertCollection(l_actual))
         .to_equal(anydata.convertCollection(l_expected));      
   END test_get_dep_cols_from_query;

   --
   -- test_get_dep_cols_from_view
   --
   PROCEDURE test_get_dep_cols_from_view IS
      l_actual   t_col_type;
      l_expected t_col_type;
   BEGIN
      l_actual := lineage_util.get_dep_cols_from_view(
                     USER,
                     'SOURCE_VIEW',
                     'SALARY',
                     0
                  );
      ut.expect(l_actual.count).to_equal(2);
      l_expected := t_col_type(
                       col_type(USER, 'TABLE', 'EMP', 'COMM'),
                       col_type(USER, 'TABLE', 'EMP', 'SAL')
                    );
      ut.expect(anydata.convertCollection(l_actual))
         .to_equal(anydata.convertCollection(l_expected));         
   END test_get_dep_cols_from_view;

   --
   -- test_get_dep_cols_from_insert
   --
   PROCEDURE test_get_dep_cols_from_insert IS
      l_signature VARCHAR2(32 BYTE);
      l_actual    t_col_lineage_type;
      l_sorted    t_col_lineage_type;
      l_expected  t_col_lineage_type;
   BEGIN
      SELECT signature
        INTO l_signature
        FROM user_statements
       WHERE text = 'INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY) SELECT DEPT_NO, DEPT_NAME, SALARY FROM SOURCE_SYN';
      -- non-recursive
      l_actual := lineage_util.get_dep_cols_from_insert(l_signature, 0);
      ut.expect(l_actual.count).to_equal(3);
      SELECT col_lineage_type(
                from_owner,
                from_object_type,
                from_object_name,
                from_column_name,
                to_owner,
                to_object_type,
                to_object_name,
                to_column_name
             )
        BULK COLLECT INTO l_sorted
        FROM TABLE(l_actual)
       ORDER BY from_owner, from_object_type, from_object_name, from_column_name,
             to_owner, to_object_type, to_object_name, to_column_name;      
      l_expected := t_col_lineage_type(
                       col_lineage_type(USER, 'VIEW', 'SOURCE_VIEW', 'DEPT_NAME', USER, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_lineage_type(USER, 'VIEW', 'SOURCE_VIEW', 'DEPT_NO', USER, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_lineage_type(USER, 'VIEW', 'SOURCE_VIEW', 'SALARY', USER, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(anydata.convertCollection(l_sorted))
         .to_equal(anydata.convertCollection(l_expected));
      -- recursive
      l_actual := lineage_util.get_dep_cols_from_insert(l_signature, 1);
      ut.expect(l_actual.count).to_equal(7);
      SELECT col_lineage_type(
                from_owner,
                from_object_type,
                from_object_name,
                from_column_name,
                to_owner,
                to_object_type,
                to_object_name,
                to_column_name
             )
        BULK COLLECT INTO l_sorted
        FROM TABLE(l_actual)
       ORDER BY from_owner, from_object_type, from_object_name, from_column_name,
             to_owner, to_object_type, to_object_name, to_column_name;   
      l_expected := t_col_lineage_type(
                       col_lineage_type(USER, 'TABLE', 'DEPT', 'DEPTNO', USER, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_lineage_type(USER, 'TABLE', 'DEPT', 'DNAME', USER, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_lineage_type(USER, 'TABLE', 'EMP', 'COMM', USER, 'TABLE', 'DEPTSAL', 'SALARY'),
                       col_lineage_type(USER, 'TABLE', 'EMP', 'SAL', USER, 'TABLE', 'DEPTSAL', 'SALARY'),
                       col_lineage_type(USER, 'VIEW', 'SOURCE_VIEW', 'DEPT_NAME', USER, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_lineage_type(USER, 'VIEW', 'SOURCE_VIEW', 'DEPT_NO', USER, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_lineage_type(USER, 'VIEW', 'SOURCE_VIEW', 'SALARY', USER, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(anydata.convertCollection(l_sorted))
         .to_equal(anydata.convertCollection(l_expected));
   END test_get_dep_cols_from_insert;
   
   --
   -- test_get_target_cols_from_insert
   --
   PROCEDURE test_get_target_cols_from_insert IS
      l_signature VARCHAR2(32 BYTE);
      l_actual   t_col_type;
      l_expected t_col_type;
   BEGIN
      -- explicit target columns
      SELECT signature
        INTO l_signature
        FROM user_statements
       WHERE text = 'INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY) SELECT DEPT_NO, DEPT_NAME, SALARY FROM SOURCE_SYN';
      l_actual := lineage_util.get_target_cols_from_insert(l_signature);
      ut.expect(l_actual.count).to_equal(3);
      l_expected := t_col_type(
                       col_type(USER, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_type(USER, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_type(USER, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(anydata.convertCollection(l_actual))
         .to_equal(anydata.convertCollection(l_expected));
      -- implicit target columns
      SELECT signature
        INTO l_signature
        FROM user_statements
       WHERE text = 'INSERT INTO DEPTSAL SELECT T.* FROM SOURCE_SYN T';
      l_actual := lineage_util.get_target_cols_from_insert(l_signature);
      ut.expect(l_actual.count).to_equal(3);
      l_expected := t_col_type(
                       col_type(USER, 'TABLE', 'DEPTSAL', 'DEPT_NO'),
                       col_type(USER, 'TABLE', 'DEPTSAL', 'DEPT_NAME'),
                       col_type(USER, 'TABLE', 'DEPTSAL', 'SALARY')
                    );
      ut.expect(anydata.convertCollection(l_actual))
         .to_equal(anydata.convertCollection(l_expected));
   END test_get_target_cols_from_insert;

END test_lineage_util;
/
