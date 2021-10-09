create or replace view source_view (
   dept_no,
   dept_name,
   salary
) as
   select /*+ordered */ d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal
     from dept d
     left join (select * from emp where hiredate > date '1980-01-01') e
       on e.deptno = d.deptno
    group by d.deptno, d.dname;
