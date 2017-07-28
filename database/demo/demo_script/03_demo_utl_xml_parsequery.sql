-- 1. parse a select statement using sys.utl_xml.parsequery
SELECT parse_util.parse_query(
          in_parse_user => user, 
          in_query      => q'[
             SELECT /*+ordered */ d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
               FROM dept d
               LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                 ON e.deptno = d.deptno
              GROUP BY d.deptno, d.dname
          ]'
       ) 
  FROM dual;

-- 2. parse an insert statement using sys.utl_xml.parsequery
SELECT parse_util.parse_query(
          in_parse_user => user, 
          in_query      => q'[
             INSERT INTO deptsal (dept_no, dept_name, salary)
             SELECT /*+ordered */ d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
               FROM dept d
               LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                 ON e.deptno = d.deptno
              GROUP BY d.deptno, d.dname
          ]'
       ) 
  FROM dual; 

-- 3. parse an update statement using sys.utl_xml.parsequery
SELECT parse_util.parse_query(
          in_parse_user => user, 
          in_query      => q'[
             UPDATE deptsal
                SET salary = salary + 10
              WHERE dept_no = (SELECT deptno 
                                 FROM dept
                                WHERE dname = 'SALES')
          ]'
       ) 
  FROM dual;
 
-- 4. parse a delete statement using sys.util_xml_parsequery
SELECT parse_util.parse_query(
          in_parse_user  => user, 
          in_parse_query => q'[
             DELETE deptsal
              WHERE dept_no = (SELECT deptno 
                                 FROM dept
                                WHERE dname = 'SALES')
          ]'
       ) 
  FROM dual;
 
-- 5. parse a merge statement using sys.util_xml_parsequery
SELECT parse_util.parse_query(
          in_parse_user => user, 
          in_query      => q'[
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
          ]'
       )
  FROM dual;

-- 6. parse an anonymous PL/SQL block using sys.util_xml_parsequery - empty!
SELECT parse_util.parse_query(
         in_parse_user  => user, 
         in_parse_query => q'[
             BEGIN
                INSERT INTO deptsal (dept_no, dept_name, salary)
                SELECT /*+ordered */ d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
                  FROM dept d
                  LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                    ON e.deptno = d.deptno
                 GROUP BY d.deptno, d.dname; -- avoid premature statement termination in SQL*Plus et al.
             END; -- avoid premature statement termination in SQL*Plus et al.
          ]'
       )
  FROM dual;

-- 7. parse a select statement with a function using sys.utl_xml.parsequery - empty!
SELECT parse_util.parse_query(
          in_parse_user => user, 
          in_query      => q'[
             WITH 
                FUNCTION my_add(in_a IN NUMBER, in_b IN NUMBER) RETURN NUMBER IS
                BEGIN
                   RETURN NVL(in_a, 0) + NVL(in_b, 0); -- avoid premature statement termination in SQL*Plus et al.
                END my_add; -- avoid premature statement termination in SQL*Plus et al.
             SELECT /*+ordered */ d.deptno, d.dname, SUM(my_add(e.sal, e.comm)) AS sal
               FROM dept d
               LEFT JOIN (SELECT * FROM emp WHERE hiredate > DATE '1980-01-01') e
                 ON e.deptno = d.deptno
              GROUP BY d.deptno, d.dname
          ]'
       ) 
  FROM dual;

-- 8. parse a select statement with a 12.2 features using sys.utl_xml.parsequer
SELECT parse_util.parse_query(
          in_parse_user => user, 
          in_query      => q'[
             SELECT CAST('x' AS NUMBER DEFAULT 0 ON CONVERSION ERROR)       AS cast_col,
                    VALIDATE_CONVERSION('$29.99' AS BINARY_FLOAT, '$99D99') AS validate_col,
                    LISTAGG(
                       ename || ' (' || job || ')', 
                       ', ' ON OVERFLOW TRUNCATE '...' WITH COUNT
                    )  WITHIN GROUP (ORDER BY deptno)                       AS enames
               FROM emp
          ]'
       ) 
  FROM dual;
