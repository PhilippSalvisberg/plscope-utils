create or replace package body test_parse_util is

   --
   -- test_parse_query
   --
   procedure test_parse_query is
      l_actual   sys.xmltype;
      l_expected clob;
   begin
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
      l_actual   := parse_util.parse_query(in_parse_user => user, in_query => 'select ename from emp');
      ut.expect(l_actual.getclobval()).to_equal(l_expected);
   end test_parse_query;

   --
   -- test_get_insert_targets
   --
   procedure test_get_insert_targets is
      l_actual   t_obj_type;
      l_expected t_obj_type;
   begin
      -- single table insert
      l_expected := t_obj_type(obj_type(null, null, 'DEPT'));
      l_actual   := parse_util.get_insert_targets(
                       in_parse_user => user,
                       in_sql        => q'[
                          insert into dept values (50, 'TRAINING', 'ZURICH')
                       ]'
                    );
      ut.expect(sys.anydata.convertcollection(l_actual)).to_equal(sys.anydata.convertcollection(l_expected)).unordered;
      -- multitable insert
      l_expected := t_obj_type(
                       obj_type(null, null, 'EMP'),
                       obj_type(null, null, 'DEPT')
                    );
      l_actual   := parse_util.get_insert_targets(
                       in_parse_user => user,
                       in_sql        => q'[
                           insert all
                              when rec_type = 'EMP' then
                                 into emp (empno, ename, job, mgr, hiredate, sal, deptno)
                                 values (c1, c2, c3, c4, to_date(c5, 'YYYY-MM-DD'), c6, c7)
                              when rec_type = 'DEPT' then
                                 into dept(deptno, dname, loc)
                                 values (c1, c2, c3)
                           select 'EMP' as rec_type,
                                  '9999' as c1,
                                  'ROBERTS' as c2,
                                  'CLERK' as c3,
                                  '7788' as c4,
                                  '2017-01-01' as c5,
                                  '3000' as c6,
                                  '10' as c7
                             from dual
                           union all
                           select 'DEPT' as rec_type,
                                  '50' as c1,
                                  'TRAINING' as c2,
                                  'ZURICH' as c3,
                                  null as c4,
                                  null as c5,
                                  null as c6,
                                  null as c7
                             from dual
                       ]'
                    );
      ut.expect(sys.anydata.convertcollection(l_actual)).to_equal(sys.anydata.convertcollection(l_expected)).unordered;
   end test_get_insert_targets;

   --
   -- test_get_insert_subquery
   --
   procedure test_get_insert_subquery is
      l_actual   clob;
      l_expected clob;
   begin
      -- normal query
      l_actual   := parse_util.get_insert_subquery(q'[
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
      l_actual   := parse_util.get_insert_subquery(q'[
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
   end test_get_insert_subquery;
   
   --
   -- test_get_dep_cols
   --
   procedure test_get_dep_cols is
      l_parse_tree sys.xmltype;
      l_actual     sys.xmltype;
      l_expected   clob;
   begin
      l_parse_tree := parse_util.parse_query(
                         in_parse_user => user,
                         in_query      => q'[
                            select /*+ordered */
                                   d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal
                              from dept d
                              left join (select * from emp where hiredate > date '1980-01-01') e
                                on e.deptno = d.deptno
                             group by d.deptno, d.dname
                         ]'
                      );
      l_actual     := parse_util.get_dep_cols(in_parse_tree => l_parse_tree, in_column_pos => 3);
      l_expected   := '<column><schemaName/><tableName>EMP</tableName><columnName>SAL</columnName></column><column><schemaName/><tableName>EMP</tableName><columnName>COMM</columnName></column>';
      ut.expect(l_actual.getclobval()).to_equal(l_expected);
   end test_get_dep_cols;

end test_parse_util;
/
