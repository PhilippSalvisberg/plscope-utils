# plscope-utils - Core Database Objects

## Introduction
This component of plscope-utils provides relational views and PL/SQL packages based on PL/Scope to simplify common source code analysis tasks.

## Prerequisites

* Oracle Database 12.2.0.1 or higher
* Oracle client (SQL*Plus, SQLcl or SQL Developer) to connect to the database

## Installation

1. Clone or download this repository. Extract the downloaded zip file, if you have chosen the download option.

2. Open a terminal window and change to the directory containing this README.md file

		cd (...)

3. Create an oracle user for the plscope-utils database objects. The default username and password is ```plscope```.
   * optionally change username, password and tablespace in the installation script [database/utils/user/plscope.sql](https://github.com/PhilippSalvisberg/plscope-utils/blob/master/database/utils/user/plscope.sql)

   * connect as sys to the target database

			sqlplus / as sysdba

   * execute the script [database/utils/user/plscope.sql](https://github.com/PhilippSalvisberg/plscope-utils/blob/master/database/utils/user/plscope.sql)

			@database/utils/user/plscope.sql
			EXIT

4. Install plscope-utils

   * connect to the plscope-utils user created in the previous step

			sqlplus plscope/plscope

   * execute the script [database/install.sql](https://github.com/PhilippSalvisberg/plscope-utils/blob/master/database/install.sql)

			@database/install.sql
			EXIT

## Usage

### Compile with PL/Scope

#### Enable PL/Scope in the current session

	ALTER SESSION SET plscope_settings='identifiers:all, statements:all';

#### Create/compile a procedure

The following example is based on demo [tables](https://github.com/PhilippSalvisberg/plscope-utils/tree/master/database/demo/table) installed by plscope-utils.

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

### View PLSCOPE\_IDENTIFIERS

This view combines the ```dba_identifiers```, ```dba_statements``` and ```dba_source``` views. It provides all columns from ```dba_identifiers``` plus the following:

Column Name           | Description
--------------------- | -------------
```procedure_name```  | Name of the function/procedure in a PL/SQL package (same as ```object_name``` for standalone procedures and functions)
```procedure_scope```| ```PRIVATE``` or ```PUBLIC``` scope of a function/procedure in a PL/SQL package, children inherit the procedure scope.
```name_path```       | Context of the identifier represented as path
```path_len```        | Hierarchy level of the identifier (number of forward slashes in ```name_path```)
```ref_owner```       | ```owner``` of the object referenced by the ```signature``` column
```ref_object_type``` | ```object_type``` of the object referenced by the ```signature``` column
```ref_object_name``` | ```object_name``` of the object referenced by the ```signature``` column
```text``` | ```text``` of the referenced source code line
```parent_statement_type``` | ```type``` of the parent statement (```NULL``` if parent is not a SQL statement)
```parent_statement_signature``` | ```signature``` of the parent statement (```NULL``` if parent is not a SQL statement)
```is_used``` | ```YES``` if a declared identifier has been referenced, otherwise ```NO```. ```NULL``` when ```is_used``` is not applicable for an identifier (e.g. SQL statements).

#### Query

	SELECT procedure_name, line, col, name, name_path, path_len, type, usage,
	       ref_owner, ref_object_type, ref_object_name,
	       text, parent_statement_type, parent_statement_signature, signature
	  FROM plscope_identifiers
	 WHERE object_name = 'LOAD_FROM_TAB'
	   AND owner = USER
	 ORDER BY line, col;

#### Result

	PROCEDURE_NAME LINE  COL NAME          NAME_PATH                                            PATH_LEN TYPE      USAGE        REF_OWNER REF_OBJECT_TYPE REF_OBJECT_NAME TEXT                                                            PARENT_STATEMENT_TYPE PARENT_STATEMENT_SIGNATURE       SIGNATURE                       
	-------------- ---- ---- ------------- ---------------------------------------------------- -------- --------- ------------ --------- --------------- --------------- --------------------------------------------------------------- --------------------- -------------------------------- --------------------------------
	                  1   11 LOAD_FROM_TAB /LOAD_FROM_TAB                                              1 PROCEDURE DECLARATION  PLSCOPE   PROCEDURE       LOAD_FROM_TAB   PROCEDURE load_from_tab IS                                                                                             95BB10518161E6977D1AAAE904795B9B
	LOAD_FROM_TAB     1   11 LOAD_FROM_TAB /LOAD_FROM_TAB/LOAD_FROM_TAB                                2 PROCEDURE DEFINITION   PLSCOPE   PROCEDURE       LOAD_FROM_TAB   PROCEDURE load_from_tab IS                                                                                             95BB10518161E6977D1AAAE904795B9B
	LOAD_FROM_TAB     3    4 3nyyhcpmwxcgz /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz                  3 INSERT    EXECUTE                                                   INSERT INTO deptsal (dept_no, dept_name, salary)                                                                    0F66407F96683E82288B47C4A3692141
	LOAD_FROM_TAB     3   16 DEPTSAL       /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/DEPTSAL          4 TABLE     REFERENCE    PLSCOPE   TABLE           DEPTSAL            INSERT INTO deptsal (dept_no, dept_name, salary)             INSERT                0F66407F96683E82288B47C4A3692141 842CE56AC592888B175F02BB44BD5B94
	LOAD_FROM_TAB     3   25 DEPT_NO       /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/DEPT_NO          4 COLUMN    REFERENCE    PLSCOPE   TABLE           DEPTSAL            INSERT INTO deptsal (dept_no, dept_name, salary)             INSERT                0F66407F96683E82288B47C4A3692141 0E36BB98CA1380341FCA76D468AC332C
	LOAD_FROM_TAB     3   34 DEPT_NAME     /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/DEPT_NAME        4 COLUMN    REFERENCE    PLSCOPE   TABLE           DEPTSAL            INSERT INTO deptsal (dept_no, dept_name, salary)             INSERT                0F66407F96683E82288B47C4A3692141 4C400D0DF6CC5BD98ADBFEF88EEBC69D
	LOAD_FROM_TAB     3   45 SALARY        /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/SALARY           4 COLUMN    REFERENCE    PLSCOPE   TABLE           DEPTSAL            INSERT INTO deptsal (dept_no, dept_name, salary)             INSERT                0F66407F96683E82288B47C4A3692141 8F86A093162D45F0949E56BA145A1FE3
	LOAD_FROM_TAB     5   13 DEPTNO        /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/DEPTNO           4 COLUMN    REFERENCE    PLSCOPE   TABLE           DEPT                      d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal INSERT                0F66407F96683E82288B47C4A3692141 884839C0945B76EF500949A1737CDBEC
	LOAD_FROM_TAB     5   23 DNAME         /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/DNAME            4 COLUMN    REFERENCE    PLSCOPE   TABLE           DEPT                      d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal INSERT                0F66407F96683E82288B47C4A3692141 FECE4914A162E52126C5E631734692DA
	LOAD_FROM_TAB     5   36 SAL           /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/SAL              4 COLUMN    REFERENCE    PLSCOPE   TABLE           EMP                       d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal INSERT                0F66407F96683E82288B47C4A3692141 60535C7D73128F4E1E99B404D740FE16
	LOAD_FROM_TAB     5   48 COMM          /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/COMM             4 COLUMN    REFERENCE    PLSCOPE   TABLE           EMP                       d.deptno, d.dname, SUM(e.sal + NVL(e.comm, 0)) AS sal INSERT                0F66407F96683E82288B47C4A3692141 0DD90A25A7835C18B4B81A9F4C6FB6BA
	LOAD_FROM_TAB     6   11 DEPT          /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/DEPT             4 TABLE     REFERENCE    PLSCOPE   TABLE           DEPT                 FROM dept d                                                INSERT                0F66407F96683E82288B47C4A3692141 26739DBA3E26CBADF8B2E1FBB35428F5
	LOAD_FROM_TAB     8   24 EMP           /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/EMP              4 TABLE     REFERENCE    PLSCOPE   TABLE           EMP                               FROM emp                                      INSERT                0F66407F96683E82288B47C4A3692141 68FD9773CC24CA5C61FCE1CE2F27D0F8
	LOAD_FROM_TAB     9   24 HIREDATE      /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/HIREDATE         4 COLUMN    REFERENCE    PLSCOPE   TABLE           EMP                              WHERE hiredate > DATE '1980-01-01') e          INSERT                0F66407F96683E82288B47C4A3692141 7FDA2E553A30FF9773C84EBED43A686E
	LOAD_FROM_TAB    10   13 DEPTNO        /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/DEPTNO           4 COLUMN    REFERENCE    PLSCOPE   TABLE           EMP                    ON e.deptno = d.deptno                                   INSERT                0F66407F96683E82288B47C4A3692141 B99231DD1C6931BB3728106289DDBE98
	LOAD_FROM_TAB    10   24 DEPTNO        /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/DEPTNO           4 COLUMN    REFERENCE    PLSCOPE   TABLE           DEPT                   ON e.deptno = d.deptno                                   INSERT                0F66407F96683E82288B47C4A3692141 884839C0945B76EF500949A1737CDBEC
	LOAD_FROM_TAB    11   16 DEPTNO        /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/DEPTNO           4 COLUMN    REFERENCE    PLSCOPE   TABLE           DEPT                GROUP BY d.deptno, d.dname;                                 INSERT                0F66407F96683E82288B47C4A3692141 884839C0945B76EF500949A1737CDBEC
	LOAD_FROM_TAB    11   26 DNAME         /LOAD_FROM_TAB/LOAD_FROM_TAB/3nyyhcpmwxcgz/DNAME            4 COLUMN    REFERENCE    PLSCOPE   TABLE           DEPT                GROUP BY d.deptno, d.dname;                                 INSERT                0F66407F96683E82288B47C4A3692141 FECE4914A162E52126C5E631734692DA
	LOAD_FROM_TAB    12    4 COMMIT        /LOAD_FROM_TAB/LOAD_FROM_TAB/COMMIT                         3 COMMIT    EXECUTE                                                   COMMIT;                                                                                                             CCF976813EB05E9A94A09443EF466860

	19 rows selected.


### View PLSCOPE\_STATEMENTS

This view is based on the ```dba_statements``` view and adds a ```is_duplicate``` column.

The [etl](https://github.com/PhilippSalvisberg/plscope-utils/blob/master/database/demo/package/etl.pkb) package body contains various variants to load the ```deptsal``` target table. And the reported duplicate insert statement is used there as well.

#### Query

	SELECT line, col, type, sql_id, is_duplicate, full_text
	  FROM plscope_statements S
	 WHERE object_name = 'LOAD_FROM_TAB'
	   AND owner = USER
	 ORDER BY owner, object_type, object_name, line, col;

#### Result

	LINE  COL TYPE      SQL_ID        IS_DUPLICATE FULL_TEXT                                       
	---- ---- --------- ------------- ------------ -------------------------------------------------
	   3    4 INSERT    3nyyhcpmwxcgz YES          INSERT INTO DEPTSAL (DEPT_NO, DEPT_NAME, SALARY)
	                                               SELECT /*+ordered */ D.DEPTNO, D.DNAME, SUM(E.SAL
	                                                + NVL(E.COMM, 0)) AS SAL FROM DEPT D LEFT JOIN (
	                                               SELECT * FROM EMP WHERE HIREDATE > DATE '1980-01-
	                                               01') E ON E.DEPTNO = D.DEPTNO GROUP BY D.DEPTNO,
	                                               D.DNAME

	  12    4 COMMIT                  NO           

### View PLSCOPE\_TAB\_USAGE

This view reports table usages. It is based on the views ```dba_tables```, ```dba_dependencies``` and ```plscope_identifiers```. Usages of synonyms and views are resolved and reporteded with a ```NO``` in the column ```DIRECT_DEPENDENCY```.

#### Query

	SELECT *
	  FROM plscope_tab_usage
	 WHERE procedure_name IN ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
	   AND owner = USER
	 ORDER BY owner, object_type, object_name, line, col, direct_dependency;

#### Result

	OWNER   OBJECT_TYPE  OBJECT_NAME   LINE  COL PROCEDURE_NAME     OPERATION REF_OWNER REF_OBJECT_TYPE REF_OBJECT_NAME DIRECT_DEPENDENCY
	------- ------------ ------------- ---- ---- ------------------ --------- --------- --------------- --------------- -----------------
	PLSCOPE PACKAGE BODY ETL             14   19 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPTSAL         YES              
	PLSCOPE PACKAGE BODY ETL             16   14 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            YES              
	PLSCOPE PACKAGE BODY ETL             17   34 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           EMP             YES              
	PLSCOPE PACKAGE BODY ETL             47   19 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   TABLE           DEPTSAL         YES              
	PLSCOPE PACKAGE BODY ETL             49   14 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   TABLE           DEPT            NO               
	PLSCOPE PACKAGE BODY ETL             49   14 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   TABLE           EMP             NO               
	PLSCOPE PACKAGE BODY ETL             49   14 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   VIEW            SOURCE_VIEW     NO               
	PLSCOPE PACKAGE BODY ETL             49   14 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   SYNONYM         SOURCE_SYN      YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3   16 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPTSAL         YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    6   10 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    8   20 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           EMP             YES              

	 11 rows selected

### View PLSCOPE\_COL\_USAGE

This view reports column usages. It is based on the views ```plscope_identifiers```, ```plscope_tab_usage```, ```dba_synonyms```, ```dba_objects``` and ```dba_tab_columns```. Column-less table/view/synonym accesses are resolved and reporteded with a ```NO``` in the column ```DIRECT_DEPENDENCY```.

#### Query

	SELECT *
	  FROM plscope_col_usage
	 WHERE procedure_name IN ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
	   AND owner = USER
	 ORDER BY owner, object_type, object_name, line, col, direct_dependency;

#### Result

	OWNER   OBJECT_TYPE  OBJECT_NAME   LINE  COL PROCEDURE_NAME     OPERATION REF_OWNER REF_OBJECT_TYPE REF_OBJECT_NAME COLUMN_NAME DIRECT_DEPENDENCY
	------- ------------ ------------- ---- ---- ------------------ --------- --------- --------------- --------------- ----------- -----------------
	PLSCOPE PACKAGE BODY ETL             14   28 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPTSAL         DEPT_NO     YES              
	PLSCOPE PACKAGE BODY ETL             14   37 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPTSAL         DEPT_NAME   YES              
	PLSCOPE PACKAGE BODY ETL             14   48 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPTSAL         SALARY      YES              
	PLSCOPE PACKAGE BODY ETL             15   30 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            DEPTNO      YES              
	PLSCOPE PACKAGE BODY ETL             15   40 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            DNAME       YES              
	PLSCOPE PACKAGE BODY ETL             15   53 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           EMP             SAL         YES              
	PLSCOPE PACKAGE BODY ETL             15   65 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           EMP             COMM        YES              
	PLSCOPE PACKAGE BODY ETL             17   44 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           EMP             HIREDATE    YES              
	PLSCOPE PACKAGE BODY ETL             18   16 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           EMP             DEPTNO      YES              
	PLSCOPE PACKAGE BODY ETL             18   27 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            DEPTNO      YES              
	PLSCOPE PACKAGE BODY ETL             19   19 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            DEPTNO      YES              
	PLSCOPE PACKAGE BODY ETL             19   29 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            DNAME       YES              
	PLSCOPE PACKAGE BODY ETL             47   19 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   TABLE           DEPTSAL         DEPT_NO     NO               
	PLSCOPE PACKAGE BODY ETL             47   19 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   TABLE           DEPTSAL         SALARY      NO               
	PLSCOPE PACKAGE BODY ETL             47   19 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   TABLE           DEPTSAL         DEPT_NAME   NO               
	PLSCOPE PACKAGE BODY ETL             49   14 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   TABLE           EMP             SAL         NO               
	PLSCOPE PACKAGE BODY ETL             49   14 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   TABLE           EMP             COMM        NO               
	PLSCOPE PACKAGE BODY ETL             49   14 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   TABLE           DEPT            DNAME       NO               
	PLSCOPE PACKAGE BODY ETL             49   14 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   TABLE           DEPT            DEPTNO      NO               
	PLSCOPE PACKAGE BODY ETL             49   14 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   VIEW            SOURCE_VIEW     SALARY      NO               
	PLSCOPE PACKAGE BODY ETL             49   14 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   VIEW            SOURCE_VIEW     DEPT_NAME   NO               
	PLSCOPE PACKAGE BODY ETL             49   14 LOAD_FROM_SYN_WILD INSERT    PLSCOPE   VIEW            SOURCE_VIEW     DEPT_NO     NO               
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3   25 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPTSAL         DEPT_NO     YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3   34 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPTSAL         DEPT_NAME   YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3   45 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPTSAL         SALARY      YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    5   11 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            DEPTNO      YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    5   21 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            DNAME       YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    5   34 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           EMP             SAL         YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    5   46 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           EMP             COMM        YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    9   20 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           EMP             HIREDATE    YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB   10   12 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           EMP             DEPTNO      YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB   10   23 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            DEPTNO      YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB   11   15 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            DEPTNO      YES              
	PLSCOPE PROCEDURE    LOAD_FROM_TAB   11   25 LOAD_FROM_TAB      INSERT    PLSCOPE   TABLE           DEPT            DNAME       YES              

	 34 rows selected

### View PLSCOPE\_INS\_LINEAGE

**_Experimental_**

This view reports the [where-lineage](http://ilpubs.stanford.edu:8090/918/1/lin_final.pdf) of insert statements. It is based on the view ```plscope_identifiers``` and the PL/SQL package ```lineage_util```. Behind the scenes insert statements are processed using the undocumented PL/SQL package procedure ```sys.utl_xml.parsequery```. This procedures supports select statements quite well including Oracle 12.2 grammar enhancements. However, it does not support PL/SQL at all, not even as part of the with_clause. Hence, not all select statements produce a parse-tree. Furthermore other statements such as insert, update, delete and merge produce incomplete parse-trees, which is somehow expected for a procedure called ```ParseQuery```. However, they are still useful to e.g. identify the target tables of an insert statement.

Even if this view produces quite good results on wide range of "SELECT ... INSERT" statements, it is considered experimental. To produce reliable, more complete results a PL/SQL and SQL parser is required.

Nonetheless this view shows the power of PL/Scope and its related database features.

The example below shows that the ```salary``` column in the table ```deptsal``` is based on the columns ```sal``` and ```comm``` of the table ```emp```. Similar as in the view ```plscope_col_usage``` synonyms and view columns are resolved recursively. You may control the behaviour in the view by calling the ```lineage_util.set_recursive``` procedure before executing the query.

#### Query

	SELECT *
	  FROM plscope_ins_lineage
	 WHERE procedure_name IN ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
	 ORDER BY owner, object_type, object_name, line, col,
	       to_object_name, to_column_name,
	       from_owner, from_object_type, from_object_name, from_column_name;

#### Result (default)

	OWNER   OBJECT_TYPE  OBJECT_NAME   LINE  COL PROCEDURE_NAME     FROM_OWNER FROM_OBJECT_TYPE FROM_OBJECT_NAME FROM_COLUMN_NAME TO_OWNER TO_OBJECT_TYPE TO_OBJECT_NAME TO_COLUMN_NAME
	------- ------------ ------------- ---- ---- ------------------ ---------- ---------------- ---------------- ---------------- -------- -------------- -------------- --------------
	PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DNAME            PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
	PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DEPTNO           PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
	PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              COMM             PLSCOPE  TABLE          DEPTSAL        SALARY        
	PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              SAL              PLSCOPE  TABLE          DEPTSAL        SALARY        
	PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    TABLE            DEPT             DEPTNO           PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
	PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      DEPT_NO          PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
	PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    TABLE            EMP              COMM             PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
	PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    TABLE            EMP              SAL              PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
	PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      SALARY           PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
	PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    TABLE            DEPT             DNAME            PLSCOPE  TABLE          DEPTSAL        SALARY        
	PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      DEPT_NAME        PLSCOPE  TABLE          DEPTSAL        SALARY        
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DNAME            PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DEPTNO           PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              COMM             PLSCOPE  TABLE          DEPTSAL        SALARY        
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              SAL              PLSCOPE  TABLE          DEPTSAL        SALARY        

	 15 rows selected

#### Result (after calling ```EXEC lineage_util.set_recursive(0);```)

	OWNER   OBJECT_TYPE  OBJECT_NAME   LINE  COL PROCEDURE_NAME     FROM_OWNER FROM_OBJECT_TYPE FROM_OBJECT_NAME FROM_COLUMN_NAME TO_OWNER TO_OBJECT_TYPE TO_OBJECT_NAME TO_COLUMN_NAME
	------- ------------ ------------- ---- ---- ------------------ ---------- ---------------- ---------------- ---------------- -------- -------------- -------------- --------------
	PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DNAME            PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
	PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DEPTNO           PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
	PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              COMM             PLSCOPE  TABLE          DEPTSAL        SALARY        
	PLSCOPE PACKAGE BODY ETL             14    7 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              SAL              PLSCOPE  TABLE          DEPTSAL        SALARY        
	PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      DEPT_NO          PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
	PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      SALARY           PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
	PLSCOPE PACKAGE BODY ETL             47    7 LOAD_FROM_SYN_WILD PLSCOPE    VIEW             SOURCE_VIEW      DEPT_NAME        PLSCOPE  TABLE          DEPTSAL        SALARY        
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DNAME            PLSCOPE  TABLE          DEPTSAL        DEPT_NAME     
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            DEPT             DEPTNO           PLSCOPE  TABLE          DEPTSAL        DEPT_NO       
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              COMM             PLSCOPE  TABLE          DEPTSAL        SALARY        
	PLSCOPE PROCEDURE    LOAD_FROM_TAB    3    4 LOAD_FROM_TAB      PLSCOPE    TABLE            EMP              SAL              PLSCOPE  TABLE          DEPTSAL        SALARY        

	 11 rows selected

	 ## License

	 plscope-utils is licensed under the Apache License, Version 2.0. You may obtain a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>.
