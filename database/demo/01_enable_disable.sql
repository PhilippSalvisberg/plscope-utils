--
-- disable PL/Scope for demo objects
--
ALTER SESSION SET plscope_settings='identifiers:none, statements:none';

ALTER PACKAGE etl COMPILE;
ALTER SYNONYM source_syn COMPILE;

SELECT * FROM dba_identifiers WHERE owner = USER;
SELECT * FROM dba_statements WHERE owner = USER;

--
-- enable PL/Scope for package
--

ALTER SESSION SET plscope_settings='identifiers:all, statements:all';

ALTER PACKAGE etl COMPILE SPECIFICATION;

SELECT * from dba_identifiers WHERE owner = USER;
SELECT * from dba_statements WHERE owner = USER;

ALTER PACKAGE etl COMPILE BODY;

SELECT object_type, object_name, count(*) 
  FROM dba_identifiers 
 WHERE owner = USER
 GROUP BY object_type, object_name;

SELECT object_type, object_name, type, count(*)
  FROM dba_statements 
 WHERE owner = USER
 GROUP BY object_type, object_name, type;

--
-- enable PL/Scope for synonym§
--

ALTER SYNONYM source_syn COMPILE;

SELECT object_type, object_name, count(*) 
  FROM dba_identifiers 
 WHERE owner = USER
 GROUP BY object_type, object_name;

SELECT object_type, object_name, type, count(*)
  FROM dba_statements 
 WHERE owner = USER
 GROUP BY object_type, object_name, type;
