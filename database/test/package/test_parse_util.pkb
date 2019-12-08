CREATE OR REPLACE PACKAGE BODY test_parse_util IS

   --
   -- test_parse_query
   --
   PROCEDURE test_parse_query IS
      l_actual   xmltype;
      l_expected CLOB;
   BEGIN
      l_expected := q'[<QUERY>
  <SELECT>
    <SELECT_LIST>
      <SELECT_LIST_ITEM>
        <COLUMN_REF>
          <TABLE>EMP</TABLE>
          <COLUMN>ENAME</COLUMN>
        </COLUMN_REF>
      </SELECT_LIST_ITEM>
    </SELECT_LIST>
  </SELECT>
  <FROM>
    <FROM_ITEM>
      <TABLE>EMP</TABLE>
    </FROM_ITEM>
  </FROM>
</QUERY>
]';
      l_actual := parse_util.parse_query(USER, 'SELECT ename FROM emp');
      ut.expect(l_actual.getclobval()).to_equal(l_expected);
   END;

   --
   -- test_get_insert_targets
   --
   PROCEDURE test_get_insert_targets IS
      l_actual   t_obj_type;
      l_expected t_obj_type;
   BEGIN
      -- single table insert
      l_expected := t_obj_type(
                       obj_type(NULL, NULL, 'DEPT')
                    );
      l_actual := parse_util.get_insert_targets(
                     USER,
                     q'[
                        INSERT INTO dept VALUES (50, 'TRAINING', 'ZURICH')
                     ]'
                  );
      ut.expect(anydata.convertCollection(l_actual))
         .to_equal(anydata.convertCollection(l_expected)).unordered;
      -- multitable insert
      l_expected := t_obj_type(
                       obj_type(NULL, NULL, 'EMP'),
                       obj_type(NULL, NULL, 'DEPT')
                    );
      l_actual := parse_util.get_insert_targets(
                     USER,
                     q'[
                        INSERT ALL
                           WHEN rec_type = 'EMP' THEN
                              INTO emp (empno, ename, job, mgr, hiredate, sal, deptno)
                              VALUES (c1, c2, c3, c4, to_date(c5, 'YYYY-MM-DD'), c6, c7)
                           WHEN rec_type = 'DEPT' THEN
                              INTO dept(deptno, dname, loc)
                              VALUES (c1, c2, c3)
                        SELECT 'EMP' AS rec_type, '9999' AS c1, 
                               'ROBERTS' AS c2, 
                               'CLERK' AS c3, 
                               '7788' AS c4, 
                               '2017-01-01' AS c5, 
                               '3000' AS c6, 
                               '10' AS c7
                          FROM dual
                        UNION ALL
                        SELECT 'DEPT' AS rec_type, 
                                '50' AS c1, 
                                'TRAINING' AS c2, 
                                'ZURICH' AS c3, 
                                NULL AS c4, 
                                NULL AS c5, 
                                NULL AS c6, 
                                NULL AS c7
                           FROM dual
                     ]'
                  );
      ut.expect(anydata.convertCollection(l_actual))
         .to_equal(anydata.convertCollection(l_expected)).unordered;
   END test_get_insert_targets;

   --
   -- test_get_insert_subquery
   --
   PROCEDURE test_get_insert_subquery IS
     l_actual   CLOB;
     l_expected CLOB;
   BEGIN
      -- normal query
      l_actual := parse_util.get_insert_subquery(q'[
                     INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY)
                     SELECT /*+ordered */ 
                            d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) AS sal
                       FROM dept d
                       LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                         ON e.deptno = d.deptno
                     GROUP BY d.deptno, d.dname
                  ]');
      l_expected := q'[
                     SELECT /*+ordered */ 
                            d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) AS sal
                       FROM dept d
                       LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                         ON e.deptno = d.deptno
                     GROUP BY d.deptno, d.dname
                  ]';
      -- with_clause and error_logging_clause
      l_actual := parse_util.get_insert_subquery(q'[
                     INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY)
                     WITH result AS (
                        SELECT /*+ordered */ 
                               d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) AS sal
                          FROM dept d
                          LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                            ON e.deptno = d.deptno
                        GROUP BY d.deptno, d.dname
                     )
                     SELECT deptno, dname, sal
                       FROM result
                     LOG ERRORS INTO deptsal_err
                  ]');
      l_expected := q'[
                     WITH result AS (
                        SELECT /*+ordered */ 
                               d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) AS sal
                          FROM dept d
                          LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                            ON e.deptno = d.deptno
                        GROUP BY d.deptno, d.dname
                     )
                     SELECT deptno, dname, sal
                       FROM result
                  ]';
      ut.expect(trim(l_actual)).to_equal(trim(l_expected));
   END test_get_insert_subquery;
   
   --
   -- test_get_dep_cols
   --
   PROCEDURE test_get_dep_cols IS
      l_parse_tree XMLTYPE;
      l_actual     XMLTYPE;
      l_expected   CLOB;
   BEGIN
      l_parse_tree := parse_util.parse_query(
                         USER,
                         q'[
                            SELECT /*+ordered */ 
                                   d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) AS sal
                              FROM dept d
                              LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                                ON e.deptno = d.deptno
                            GROUP BY d.deptno, d.dname
                         ]'
                      );
      l_actual := PARSE_UTIL.GET_DEP_COLS(l_parse_tree, 3);
      l_expected := '<column><schemaName/><tableName>EMP</tableName><columnName>SAL</columnName></column><column><schemaName/><tableName>EMP</tableName><columnName>COMM</columnName></column>';
      ut.expect(l_actual.getclobval()).to_equal(l_expected); 
   END test_get_dep_cols;
   
END test_parse_util;
/
