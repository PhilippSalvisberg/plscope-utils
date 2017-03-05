CREATE OR REPLACE VIEW source_view (dept_no, dept_name, salary) AS
SELECT /*+ordered */ d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
  FROM dept d
  LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
    ON e.deptno = d.deptno
 GROUP BY d.deptno, d.dname;
