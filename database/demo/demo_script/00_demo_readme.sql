-- ## Compile with PL/Scope

-- ### Enable PL/Scope in the current session

alter session set plscope_settings = 'identifiers:all, statements:all';

-- ### Create/compile a procedure

create or replace procedure load_from_tab is
begin
   insert into deptsal (dept_no, dept_name, salary)
   select /*+ordered */
          d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal
     from dept d
     left join (
             select *
               from emp
              where hiredate > date '1980-01-01'
          ) e
       on e.deptno = d.deptno
    group by d.deptno, d.dname;
   commit;
end load_from_tab;
/

-- ## View PLSCOPE_IDENTIFIERS

-- ### Query

set pagesize 50
set linesize 500
column owner format a7
column procedure_name format a14
column line format 999
column col format 999
column path_len format 99
column name format a13
column name_path format a52
column type format a9
column usage format a12
column ref_owner format a9
column ref_object_type format a15
column ref_object_name format a15
column text format a63
column parent_statement_type format a21
column parent_statement_signature format a32
column signature format a32
select procedure_name,
       line,
       col,
       name,
       name_path,
       path_len,
       type,
       usage,
       ref_owner,
       ref_object_type,
       ref_object_name,
       text,
       parent_statement_type,
       parent_statement_signature,
       signature
  from plscope_identifiers
 where object_name = 'LOAD_FROM_TAB'
 order by line, col;

-- ## View PLSCOPE_STATEMENTS

-- ### Query

set long 10000
column full_text format a49
column is_duplicate format a12
select line, col, type, sql_id, is_duplicate, full_text
  from plscope_statements s
 where object_name = 'LOAD_FROM_TAB'
 order by owner, object_type, object_name, line, col;

-- ## View PLSCOPE_TAB_USAGE

-- ### Query

column text format a81
column direct_dependency format a17
column procedure_name format a18
select *
  from plscope_tab_usage
 where procedure_name in ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 order by owner, object_type, object_name, line, col, direct_dependency;

-- ## View PLSCOPE_COL_USAGE

-- ### Query

column text format a81
column column_name format a11
column object_name format a13
column operation format a9
select *
  from plscope_col_usage
 where procedure_name in ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 order by owner, object_type, object_name, line, col, direct_dependency;

-- ## View PLSCOPE_NAMING

-- ### Create/compile a package
create or replace package pkg is
   g_global_variable integer := 0;
   g_global_constant constant varchar2(10) := 'PUBLIC';

   procedure p(p_1 in  integer,
               p_2 out integer);
end pkg;
/

create or replace package body pkg is
   m_global_variable  integer               := 1;
   co_global_constant constant varchar2(10) := 'PRIVATE';

   function f(in_1 in integer) return integer is
      l_result integer;
   begin
      l_result := in_1 * in_1;
      return l_result;
   end f;

   procedure p(p_1 in  integer,
               p_2 out integer) is
   begin
      p_2 := f(in_1 => p_1);
   end p;
end pkg;
/

-- ### Query (default Naming Conventions)
set pagesize 50
set linesize 500
column object_type format a12
column procedure_name format a3
column type format a10
column name format a18
column message format a45
column line format 999
column col format 999
column text format a57

begin
   plscope_context.remove_all;
end;
/

select object_type, procedure_name, type, name, message, line, col, text
  from plscope_naming
 where object_name = 'PKG'
 order by object_type, line, col;

-- ### Query (adapted Naming Conventions)

begin
   plscope_context.set_attr('GLOBAL_VARIABLE_REGEX', '^(g|m)_.*');
   plscope_context.set_attr('CONSTANT_REGEX', '^(co|g)_.*');
   plscope_context.set_attr('IN_PARAMETER_REGEX', '^(in|p)_.*');
   plscope_context.set_attr('OUT_PARAMETER_REGEX', '^(out|p)_.*');
end;
/

select object_type, procedure_name, type, name, message, line, col, text
  from plscope_naming
 where owner = user
   and object_name = 'PKG'
 order by object_type, line, col;

-- ## View PLSCOPE_INS_LINEAGE

-- ### Query (default, recursive)

column owner format a7
column from_owner format a10
column from_object_type format a16
column from_object_name format a16
column from_column_name format a16
column to_owner format a8
column to_object_type format a14
column to_object_name format a14
column to_column_name format a14
column procedure_name format a18

exec lineage_util.set_recursive(1);
select *
  from plscope_ins_lineage
 where object_name in ('ETL', 'LOAD_FROM_TAB')
   and procedure_name in ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 order by owner,
       object_type,
       object_name,
       line,
       col,
       to_object_name,
       to_column_name,
       from_owner,
       from_object_type,
       from_object_name,
       from_column_name;

-- ### Query (non-recursive)

exec lineage_util.set_recursive(0);
select *
  from plscope_ins_lineage
 where object_name in ('ETL', 'LOAD_FROM_TAB')
   and procedure_name in ('LOAD_FROM_TAB', 'LOAD_FROM_SYN_WILD')
 order by owner,
       object_type,
       object_name,
       line,
       col,
       to_object_name,
       to_column_name,
       from_owner,
       from_object_type,
       from_object_name,
       from_column_name;

exec lineage_util.set_recursive(1);
