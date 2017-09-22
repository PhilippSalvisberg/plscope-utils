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
SET LINESIZE 500
COLUMN OWNER FORMAT A7
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
COLUMN TEXT FORMAT A63
COLUMN PARENT_STATEMENT_TYPE FORMAT A21
COLUMN PARENT_STATEMENT_SIGNATURE FORMAT A32
COLUMN SIGNATURE FORMAT A32
SELECT procedure_name, line, col, name, name_path, path_len, type, usage,
       ref_owner, ref_object_type, ref_object_name,
       text, parent_statement_type, parent_statement_signature, signature
  FROM plscope_identifiers
 WHERE object_name = 'LOAD_FROM_TAB'
 ORDER BY line, col;

-- ## View PLSCOPE_STATEMENTS

-- ### Query

SET LONG 10000
COLUMN FULL_TEXT FORMAT A49
COLUMN IS_DUPLICATE FORMAT A12
SELECT line, col, type, sql_id, is_duplicate, full_text
  FROM plscope_statements S
 WHERE object_name = 'LOAD_FROM_TAB'
 ORDER BY owner, object_type, object_name, line, col;

-- ## View PLSCOPE_TAB_USAGE

-- ### Query

COLUMN TEXT FORMAT A81
COLUMN DIRECT_DEPENDENCY FORMAT A17
COLUMN PROCEDURE_NAME FORMAT A18
SELECT *
  FROM plscope_tab_usage
 WHERE procedure_name IN ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 ORDER BY owner, object_type, object_name, line, col, direct_dependency;

-- ## View PLSCOPE_COL_USAGE

-- ### Query

COLUMN TEXT FORMAT A81
COLUMN COLUMN_NAME FORMAT A11
COLUMN OBJECT_NAME FORMAT A13
COLUMN OPERATION FORMAT A9
SELECT *
  FROM plscope_col_usage
 WHERE procedure_name IN ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 ORDER BY owner, object_type, object_name, line, col, direct_dependency;

-- ## View PLSCOPE_NAMING

-- ### Create/compile a package
CREATE OR REPLACE PACKAGE pkg IS
   g_global_variable INTEGER := 0;
   g_global_constant CONSTANT VARCHAR2(10) := 'PUBLIC';

   PROCEDURE p(p_1 IN INTEGER, p_2 OUT INTEGER);
END pkg;
/

CREATE OR REPLACE PACKAGE BODY pkg IS
   m_global_variable  INTEGER := 1;
   co_global_constant CONSTANT VARCHAR2(10) := 'PRIVATE';

   FUNCTION f(in_1 IN INTEGER) RETURN INTEGER IS
      l_result INTEGER;
   BEGIN
    l_result := in_1 * in_1;
      RETURN l_result;
   END f;

   PROCEDURE p(p_1 IN INTEGER, p_2 OUT INTEGER) IS
   BEGIN
      p_2 := f(in_1 => p_1);
   END p;
END pkg;
/

-- ### Query (default Naming Conventions)
SET PAGESIZE 50
SET LINESIZE 500
COLUMN OBJECT_TYPE FORMAT A12
COLUMN PROCEDURE_NAME FORMAT A3
COLUMN TYPE FORMAT A10
COLUMN NAME FORMAT A18
COLUMN MESSAGE FORMAT A45
COLUMN LINE FORMAT 999
COLUMN COL FORMAT 999
COLUMN TEXT FORMAT A57

BEGIN
   plscope_context.remove_all;
END;
/

SELECT object_type, procedure_name, type, name, message, line, col, text
  FROM plscope_naming
 WHERE object_name = 'PKG'
 ORDER BY object_type, line, col;

-- ### Query (adapted Naming Conventions)

BEGIN
   plscope_context.set_attr('GLOBAL_VARIABLE_REGEX', '^(g|m)_.*');
   plscope_context.set_attr('CONSTANT_REGEX',        '^(co|g)_.*');
   plscope_context.set_attr('IN_PARAMETER_REGEX',    '^(in|p)_.*');
   plscope_context.set_attr('OUT_PARAMETER_REGEX',   '^(out|p)_.*');
END;
/

SELECT object_type, procedure_name, type, name, message, line, col, text
  FROM plscope_naming
 WHERE owner = USER
   AND object_name = 'PKG'
 ORDER BY object_type, line, col;

-- ## View PLSCOPE_INS_LINEAGE

-- ### Query (default, recursive)

COLUMN OWNER FORMAT A7
COLUMN FROM_OWNER FORMAT A10
COLUMN FROM_OBJECT_TYPE FORMAT A16
COLUMN FROM_OBJECT_NAME FORMAT A16
COLUMN FROM_COLUMN_NAME FORMAT A16
COLUMN TO_OWNER FORMAT A8
COLUMN TO_OBJECT_TYPE FORMAT A14
COLUMN TO_OBJECT_NAME FORMAT A14
COLUMN TO_COLUMN_NAME FORMAT A14
COLUMN PROCEDURE_NAME FORMAT A18

EXEC lineage_util.set_recursive(1);
SELECT *
  FROM plscope_ins_lineage
 WHERE object_name IN ('ETL', 'LOAD_FROM_TAB')
   AND procedure_name IN ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 ORDER BY owner, object_type, object_name, line, col,
       to_object_name, to_column_name,
       from_owner, from_object_type, from_object_name, from_column_name;

-- ### Query (non-recursive)

EXEC lineage_util.set_recursive(0);
SELECT *
  FROM plscope_ins_lineage
 WHERE object_name IN ('ETL', 'LOAD_FROM_TAB')
   AND procedure_name IN ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 ORDER BY owner, object_type, object_name, line, col,
       to_object_name, to_column_name,
       from_owner, from_object_type, from_object_name, from_column_name;

EXEC lineage_util.set_recursive(1);
