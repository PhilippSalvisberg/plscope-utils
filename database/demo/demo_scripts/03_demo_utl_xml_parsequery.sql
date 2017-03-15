-- 1. parse a select statement using sys.utl_xml.parsequery
SELECT parse_util.parse_query(user, q'[
         SELECT /*+ordered */ d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
           FROM dept d
           LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
             ON e.deptno = d.deptno
          GROUP BY d.deptno, d.dname
       ]') 
  FROM dual;

-- 2. parse an insert statement using sys.utl_xml.parsequery
SELECT parse_util.parse_query(user, q'[
         INSERT INTO deptsal (dept_no, dept_name, salary)
         SELECT /*+ordered */ d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
           FROM dept d
           LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
             ON e.deptno = d.deptno
          GROUP BY d.deptno, d.dname
       ]') 
  FROM dual; 

-- 3. parse an update statement using sys.utl_xml.parsequery
SELECT parse_util.parse_query(user, q'[
         UPDATE deptsal
            SET salary = salary + 10
          WHERE dept_no = (SELECT deptno 
                             FROM dept
                            WHERE dname = 'SALES')
       ]') 
  FROM dual;
 
-- 4. parse a delete statement using sys.util_xml_parsequery
SELECT parse_util.parse_query(user, q'[
         DELETE deptsal
          WHERE dept_no = (SELECT deptno 
                             FROM dept
                            WHERE dname = 'SALES')
       ]') 
  FROM dual;
 
-- 5. parse a merge statement using sys.util_xml_parsequery
SELECT parse_util.parse_query(user, q'[
          MERGE INTO deptsal t
          USING (
                  SELECT /*+ordered */ d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
                    FROM dept d
                    LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                      ON e.deptno = d.deptno
                   GROUP BY d.deptno, d.dname
                ) s
             ON (t.dept_no = s.deptno)
          WHEN MATCHED THEN 
             UPDATE SET t.salary = s.sal * 0.1
          WHEN NOT MATCHED THEN
             INSERT (t.dept_no, t.dept_name, t.salary)
             VALUES (s.deptno, s.dname, s.sal * 0.1)
       ]')
  FROM dual;

-- 6. parse an anonymous PL/SQL block using sys.util_xml_parsequery - empty!
SELECT parse_util.parse_query(user, q'[
         BEGIN
            INSERT INTO deptsal (dept_no, dept_name, salary)
            SELECT /*+ordered */ d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
              FROM dept d
              LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                ON e.deptno = d.deptno
             GROUP BY d.deptno, d.dname;
         END;
       ]')
  FROM dual;
