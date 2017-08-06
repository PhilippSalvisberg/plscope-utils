-- 1. enable PL/Scope in session
ALTER SESSION SET plscope_settings='identifiers:all, statements:all';

CREATE OR REPLACE PROCEDURE load_from_tab IS
BEGIN
   INSERT INTO deptsal (dept_no, dept_name, salary)
   SELECT /*+ordered */
          d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal
     FROM dept d
     LEFT JOIN (SELECT * 
                  FROM emp 
                 WHERE hiredate > DATE '1980-01-01') e
	   ON e.deptno = d.deptno
    GROUP BY d.deptno, d.dname;
   COMMIT;
END load_from_tab;
/

-- 2. query original PL/Scope identifiers 
SELECT line, col, name, type, usage, signature, -- SELECT * FROM all_identifiers WHERE type = 'TABLE' AND usage = 'DECLARATION'
       usage_id, usage_context_id
  FROM user_identifiers
 WHERE object_name = 'LOAD_FROM_TAB'
 ORDER BY line, col;
 
-- 3. query original PL/Scope statements
SELECT line, col, sql_id, type, full_text, has_hint, signature, usage_id, usage_context_id
  FROM user_statements
 WHERE object_name = 'LOAD_FROM_TAB'
 ORDER BY line, col;
 
-- 4. combine identifiers and statements, report hierarchy level, references
WITH 
   ids AS (
      SELECT name, 
             signature, 
             type, 
             object_name, 
             object_type, 
             usage, 
             usage_id, 
             line, 
             col, 
             usage_context_id,
             origin_con_id
        FROM user_identifiers
      UNION ALL
      SELECT NVL(sql_id, type) AS name, 
             signature, 
             type, 
             object_name, 
             object_type, 
             'EXECUTE' AS usage, -- new, artificial usage
             usage_id, 
             line, 
             col, 
             usage_context_id,
             origin_con_id            
       FROM user_statements
   )
 SELECT ids.line, 
        ids.col,
        ids.name,
        sys_connect_by_path(replace(ids.name,'/'), '/') AS name_path,
        ids.type,
        ids.usage, 
        refs.object_type AS ref_object_type,
        refs.object_name AS ref_object_name
   FROM ids
   LEFT JOIN user_identifiers refs 
     ON refs.signature = ids.signature
        AND refs.usage = 'DECLARATION'
  WHERE ids.object_name = 'LOAD_FROM_TAB'
  START WITH ids.usage_context_id = 0
CONNECT BY  PRIOR ids.usage_id    = ids.usage_context_id
        AND PRIOR ids.object_type = ids.object_type
        AND PRIOR ids.object_name = ids.object_name
  ORDER BY ids.line, ids.col;

-- 5. query plscope-utils identifiers
SELECT line, col, name, name_path, type, usage, 
       ref_owner, ref_object_type, ref_object_name
  FROM plscope_identifiers
 WHERE object_name = 'LOAD_FROM_TAB'
 ORDER BY line, col;

-- 6. query all columns in plscope-utils identifiers
SELECT *
  FROM plscope_identifiers
 WHERE object_name = 'LOAD_FROM_TAB'
 ORDER BY line, col;
 
-- 7. query plscope-utils statements (adds a is_duplicate column)
SELECT * 
  FROM plscope_statements
 WHERE object_name = 'LOAD_FROM_TAB'
 ORDER BY owner, object_type, object_name, line, col;
   
-- 8. query duplicate statements
SELECT * 
  FROM plscope_statements
 WHERE is_duplicate = 'YES';
