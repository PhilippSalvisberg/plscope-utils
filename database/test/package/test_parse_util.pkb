create or replace package body test_parse_util is

   co_plsql_unit_owner constant user_users.username%type := $$PLSQL_UNIT_OWNER;

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
      l_actual   := parse_util.parse_query(in_parse_user => co_plsql_unit_owner, in_query => 'select ename from emp');
      ut.expect(l_actual.getclobval()).to_equal(l_expected);
   end test_parse_query;

   --
   -- test_get_insert_targets
   --
   procedure test_get_insert_targets is
      t_actual   t_obj_type;
      t_expected t_obj_type;
   begin
      -- single table insert
      t_expected := t_obj_type(obj_type(null, null, 'DEPT'));
      t_actual   := parse_util.get_insert_targets(
                       in_parse_user => co_plsql_unit_owner,
                       in_sql        => q'[
                          insert into dept values (50, 'TRAINING', 'ZURICH')
                       ]'
                    );
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
      -- multitable insert
      t_expected := t_obj_type(
                       obj_type(null, null, 'EMP'),
                       obj_type(null, null, 'DEPT')
                    );
      t_actual   := parse_util.get_insert_targets(
                       in_parse_user => co_plsql_unit_owner,
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
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
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
                      insert into DEPTSAL (DEPT_NO, DEPT_NAME, SALARY)
                      select /*+ordered */
                             d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal
                        from dept d
                        left join (select * from emp where hiredate > date '1980-01-01') e
                          on e.deptno = d.deptno
                       group by d.deptno, d.dname
                    ]');
      l_expected := q'[
                       select /*+ordered */
                              d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal
                         from dept d
                         left join (select * from emp where hiredate > date '1980-01-01') e
                           on e.deptno = d.deptno
                        group by d.deptno, d.dname
                    ]';
      -- with_clause and error_logging_clause
      l_actual   := parse_util.get_insert_subquery(q'[
                       insert into DEPTSAL (DEPT_NO, DEPT_NAME, SALARY)
                       with result as (
                             select /*+ordered */
                                    d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal
                               from dept d
                               left join (select * from emp where hiredate > date '1980-01-01') e
                                 on e.deptno = d.deptno
                              group by d.deptno, d.dname
                          )
                       select deptno, dname, sal
                         from result
                          log errors into deptsal_err
                    ]');
      l_expected := q'[
                       with result as (
                             select /*+ordered */
                                    d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal
                               from dept d
                               left join (select * from emp where hiredate > date '1980-01-01') e
                                 on e.deptno = d.deptno
                              group by d.deptno, d.dname
                          )
                       select deptno, dname, sal
                         from result
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
                         in_parse_user => co_plsql_unit_owner,
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
