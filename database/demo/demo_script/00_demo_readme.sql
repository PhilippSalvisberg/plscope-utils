-- ## Compile with PL/Scope

-- ### Enable PL/Scope in the current session

ALTER SESSION SET plscope_settings='identifiers:all, statements:all';

-- ### Create/compile a procedure

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

-- ## View PLSCOPE_IDENTIFIERS

-- ### Query

SET PAGESIZE 50
COLUMN PROCEDURE_NAME FORMAT A14
COLUMN LINE FORMAT 999
COLUMN COL FORMAT 999
COLUMN PATH_LEN FORMAT 99
COLUMN NAME FORMAT A13
COLUMN NAME_PATH FORMAT A52
COLUMN TYPE FORMAT A9
COLUMN USAGE FORMAT A12
COLUMN REF_OWNER FORMAT A9
COLUMN REF_OBJECT_TYPE FORMAT A15
COLUMN REF_OBJECT_NAME FORMAT A15
SELECT procedure_name, line, col, name, name_path, path_len, type, usage, 
       ref_owner, ref_object_type, ref_object_name
  FROM plscope_identifiers
 WHERE object_name = 'LOAD_FROM_TAB'
   AND owner = USER
 ORDER BY line, col;
 
-- ## View PLSCOPE_STATEMENTS

-- ### Query

SET LONG 10000
COLUMN FULL_TEXT FORMAT A49
COLUMN IS_DUPLICATE FORMAT A12
SELECT line, col, type, sql_id, is_duplicate, full_text
  FROM plscope_statements S
 WHERE object_name = 'LOAD_FROM_TAB'
   AND owner = USER
 ORDER BY owner, object_type, object_name, line, col;
 
-- ## View PLSCOPE_TAB_USAGE

-- ### Query

COLUMN DIRECT_DEPENDENCY FORMAT A17
COLUMN PROCEDURE_NAME FORMAT A18
SELECT * 
  FROM plscope_tab_usage
 WHERE procedure_name IN ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
   AND owner = USER
 ORDER BY owner, object_type, object_name, line, col, direct_dependency;

-- ## View PLSCOPE_COL_USAGE

-- ### Query

COLUMN COLUMN_NAME FORMAT A11
COLUMN OBJECT_NAME FORMAT A13
COLUMN OPERATION FORMAT A9
SELECT * 
  FROM plscope_col_usage
 WHERE procedure_name IN ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
   AND owner = USER
 ORDER BY owner, object_type, object_name, line, col, direct_dependency;

-- ## View PLSCOPE_INS_LINEAGE

-- ### Query

COLUMN FROM_OWNER FORMAT A10
COLUMN FROM_OBJECT_TYPE FORMAT A16
COLUMN FROM_OBJECT_NAME FORMAT A16
COLUMN FROM_COLUMN_NAME FORMAT A16
COLUMN TO_OWNER FORMAT A8
COLUMN TO_OBJECT_TYPE FORMAT A14
COLUMN TO_OBJECT_NAME FORMAT A14
COLUMN TO_COLUMN_NAME FORMAT A14
COLUMN PROCEDURE_NAME FORMAT A18
SELECT *
  FROM plscope_ins_lineage
 WHERE procedure_name IN ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 ORDER BY owner, object_type, object_name, line, col, 
       to_object_name, to_column_name, 
       from_owner, from_object_type, from_object_name, from_column_name;